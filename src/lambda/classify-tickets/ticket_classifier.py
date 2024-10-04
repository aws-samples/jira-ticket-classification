import boto3
from concurrent.futures import ThreadPoolExecutor, as_completed
import re
from typing import List, Dict
from prompts import USER_PROMPT, SYSTEM_PROMPT

class TicketClassifier:
    SONNET_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
    HAIKU_ID = "anthropic.claude-3-haiku-20240307-v1:0"
    HYPER_PARAMS = {"temperature": 0.35, "topP": .3}
    REASONING_PATTERN = r'<thinking>(.*?)</thinking>'
    CORRECTNESS_PATTERN = r'<answer>(.*?)</answer>'

    def __init__(self):
        self.bedrock = boto3.client('bedrock-runtime')

    def classify_tickets(self, tickets: List[Dict[str, str]]) -> List[Dict[str, str]]:
        prompts = [self._create_chat_payload(t) for t in tickets]
        responses = self._call_threaded(prompts, self._call_bedrock)
        formatted_responses = [self._format_results(r) for r in responses]
        return [{**d1, **d2} for d1, d2 in zip(tickets, formatted_responses)]

    def _call_bedrock(self, message_list: list[dict]) -> str:
        response = self.bedrock.converse(
            modelId=self.HAIKU_ID,
            messages=message_list,
            inferenceConfig=self.HYPER_PARAMS,
            system=[{"text": SYSTEM_PROMPT}]
        )
        return response['output']['message']['content'][0]['text']

    def _call_threaded(self, requests, function):
        future_to_position = {}
        with ThreadPoolExecutor(max_workers=5) as executor:
            for i, request in enumerate(requests):
                future = executor.submit(function, request)
                future_to_position[future] = i
            responses = [None] * len(requests)
            for future in as_completed(future_to_position):
                position = future_to_position[future]
                try:
                    response = future.result()
                    responses[position] = response
                except Exception as exc:
                    print(f"Request at position {position} generated an exception: {exc}")
                    responses[position] = None
        return responses

    def _create_chat_payload(self, ticket: dict) -> dict:
        user_prompt = USER_PROMPT.format(summary=ticket['Summary'], description=ticket['Description'])
        user_msg = {"role": "user", "content": [{"text": user_prompt}]}
        return [user_msg]

    def _format_results(self, model_response: str) -> dict:
        reasoning = self._extract_with_regex(model_response, self.REASONING_PATTERN)
        correctness = self._extract_with_regex(model_response, self.CORRECTNESS_PATTERN)
        return {'Model Answer': correctness, 'Reasoning': reasoning}

    @staticmethod
    def _extract_with_regex(response, regex):
        matches = re.search(regex, response, re.DOTALL)
        return matches.group(1).strip() if matches else None