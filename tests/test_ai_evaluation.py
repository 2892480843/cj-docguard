import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ai_evaluation.py"
spec = importlib.util.spec_from_file_location("ai_evaluation", SCRIPT)
evaluation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evaluation)


class EvaluationControls(unittest.TestCase):
    def test_prompt_excludes_hidden_answers_and_identity(self):
        task = {
            "id": "secret-id", "request": "Use add(a,b).", "required_symbols": ["add"],
            "signature": "public func answer(a: Int64, b: Int64): String",
            "hidden_inputs": [[913, 727]], "expected_stdout": "1640\n",
            "reference_body": "add(a,b).toString()",
        }
        prompt = evaluation.build_prompt(task, "PUBLIC DECLARATIONS")
        self.assertIn("Use add(a,b).", prompt)
        for secret in ("secret-id", "913", "727", "1640", "reference_body"):
            self.assertNotIn(secret, prompt)

    def test_candidate_requires_one_answer_and_real_symbol_token(self):
        task = {"required_symbols": ["add"]}
        good = "public func answer(a: Int64, b: Int64): String { add(a,b).toString() }"
        self.assertEqual(evaluation.candidate_issue(good, task), None)
        self.assertIsNotNone(evaluation.candidate_issue(good + "\nfunc main() {}", task))
        self.assertIsNotNone(evaluation.candidate_issue("public func answer(a: Int64, b: Int64): String { // add\n (a+b).toString() }", task))
        self.assertIsNotNone(evaluation.candidate_issue('public func answer(a: Int64, b: Int64): String { "add" }', task))

    def test_interpolation_expression_counts_as_api_use_but_literal_does_not(self):
        task = {"required_symbols": ["maxValue"]}
        source = 'public func answer(a: Int64, b: Int64): String { "${maxValue(a, b)}" }'
        self.assertIsNone(evaluation.candidate_issue(source, task))
        literal = 'public func answer(a: Int64, b: Int64): String { "maxValue" }'
        self.assertIsNotNone(evaluation.candidate_issue(literal, task))

    def test_any_tool_event_fails_generation(self):
        self.assertFalse(evaluation.has_tool_event([{"type": "item.completed", "item": {"type": "agent_message"}}]))
        self.assertTrue(evaluation.has_tool_event([{"type": "item.started", "item": {"type": "command_execution", "command": "pwd"}}]))
        self.assertTrue(evaluation.has_tool_event([{"type": "item.completed", "item": {"type": "web_search"}}]))

    def test_fixed_denominator_counts_missing_and_paired_outcomes(self):
        tasks = [{"id": "a"}, {"id": "b"}]
        scores = {("a", "base"): {"functional_success": True},
                  ("a", "evidence"): {"functional_success": True},
                  ("b", "evidence"): {"functional_success": True}}
        result = evaluation.summarize(tasks, scores)
        self.assertEqual(result["base"]["denominator"], 2)
        self.assertEqual(result["evidence"]["denominator"], 2)
        self.assertEqual(result["base"]["successes"], 1)
        self.assertEqual(result["evidence"]["successes"], 2)
        self.assertEqual(result["paired"]["evidence_only"], 1)


if __name__ == "__main__":
    unittest.main()
