#!/usr/bin/env python3
"""Convert emotion2vec+ seed (language-agnostic SER) to Core ML for PhutPlae.

Run on a Mac with Python 3.10+, then AirDrop / copy the .mlpackage into the
app's Application Support/SER folder or zip it for the in-app pack download.

    python3 scripts/convert_emotion2vec_seed_to_coreml.py --out ./Emotion2VecPlusSeed.mlpackage

The converter prefers FunASR (`iic/emotion2vec_plus_seed`). If that stack is
not installed it still writes a same-shaped Core ML graph so Xcode can compile
the I/O contract; replace it with a real conversion before travel.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


WINDOW = 32_000  # 2.0 s @ 16 kHz
CLASSES = 9


def convert_funasr(out: Path) -> None:
    import coremltools as ct
    import numpy as np
    import torch

    from funasr import AutoModel

    bundle = AutoModel(model="iic/emotion2vec_plus_seed")
    module = bundle.model
    module.eval()

    class UtteranceWrapper(torch.nn.Module):
        def __init__(self, inner):
            super().__init__()
            self.inner = inner

        def forward(self, audio: torch.Tensor) -> torch.Tensor:
            # audio: [1, T] float32, 16 kHz
            wav = audio.squeeze(0)
            result = self.inner.inference(
                data_in=[wav.cpu().numpy()],
                granularity="utterance",
                extract_embedding=False,
            )
            scores = result[0]["scores"]
            return torch.tensor(scores, dtype=torch.float32).unsqueeze(0)

    example = torch.zeros(1, WINDOW)
    traced = torch.jit.trace(UtteranceWrapper(module), example, check_trace=False)
    mlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="audio", shape=(1, WINDOW), dtype=np.float32)],
        outputs=[ct.TensorType(name="logits")],
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=ct.precision.FLOAT16,
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(out))
    print(f"Wrote {out}")


def write_io_stub(out: Path) -> None:
    """Last-resort graph with the production I/O names/shapes."""
    import coremltools as ct
    import numpy as np
    from coremltools.models.neural_network import NeuralNetworkBuilder
    from coremltools.models.utils import save_spec

    builder = NeuralNetworkBuilder(
        input_features=[("audio", (1, WINDOW))],
        output_features=[("logits", (1, CLASSES))],
        disable_rank5_shape_mapping=True,
    )
    # Mean-pool the waveform then a dense layer so the spec is a valid ML model.
    builder.add_reduce_mean("pool", input_name="audio", output_name="pooled", axes=[1], keepdims=False)
    rng = np.random.default_rng(0)
    w = (rng.normal(0, 0.01, size=(CLASSES, 1))).astype(np.float32)
    b = np.zeros((CLASSES,), dtype=np.float32)
    builder.add_inner_product(
        name="cls",
        input_name="pooled",
        output_name="logits",
        input_channels=1,
        output_channels=CLASSES,
        W=w,
        b=b,
        has_bias=True,
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    save_spec(builder.spec, str(out))
    print(
        f"Wrote I/O stub at {out}. This is NOT the trained SER. "
        "Install funasr + coremltools and rerun for travel-quality weights.",
        file=sys.stderr,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=Path("Emotion2VecPlusSeed.mlpackage"))
    parser.add_argument("--stub", action="store_true", help="Write I/O stub only")
    args = parser.parse_args()
    if args.stub:
        write_io_stub(args.out)
        return 0
    try:
        convert_funasr(args.out)
        return 0
    except Exception as exc:  # noqa: BLE001
        print(f"FunASR conversion failed: {exc}", file=sys.stderr)
        write_io_stub(args.out)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
