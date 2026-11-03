import Foundation

enum ChatPromptFormatter {
    static func render(system: String, user: String, family: PromptFamily) -> String {
        switch family {
        case .qwen:
            return """
            <|im_start|>system
            \(system)<|im_end|>
            <|im_start|>user
            \(user)<|im_end|>
            <|im_start|>assistant

            """
        case .llama3:
            return """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>

            \(system)<|eot_id|><|start_header_id|>user<|end_header_id|>

            \(user)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

            """
        }
    }
}
