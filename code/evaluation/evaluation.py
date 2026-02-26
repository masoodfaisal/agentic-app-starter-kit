"""
Happy Path Evaluation for LangGraph Agent
Validates core agent flows with assertions on tool usage and responses.
"""
import asyncio
import httpx
import json
from dataclasses import dataclass
from typing import Optional
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor

# Setup tracing for evaluation
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
tracer = trace.get_tracer("agent-eval")

AGENT_URL = "http://localhost:8000/chat"


@dataclass
class TestCase:
    name: str
    messages: list[str]  # Sequence of messages to send
    expected_tools: list[list[str]]  # Expected tools per message
    expected_in_response: list[str]  # Strings that should appear in final response
    description: str = ""


# Define happy path test cases
HAPPY_PATH_TESTS = [
    TestCase(
        name="simple_greeting",
        messages=["Hello!"],
        expected_tools=[[]],  # No tools expected
        expected_in_response=["hello", "hi", "hey"],
        description="Agent should respond naturally without tools"
    ),
    TestCase(
        name="save_memory_name",
        messages=["My name is Alice"],
        expected_tools=[["save_memory"]],
        expected_in_response=["alice", "remember", "noted", "saved"],
        description="Agent should save user's name to memory"
    ),
    TestCase(
        name="save_memory_favourite_fruit",
        messages=["My favourite fruit is mango"],
        expected_tools=[["save_memory"]],
        expected_in_response=["mango", "remember", "noted", "saved"],
        description="Agent should save user's favourite fruit"
    ),
    TestCase(
        name="direct_fruit_price",
        messages=["What is the price of apples?"],
        expected_tools=[["get_fruit_price"]],
        expected_in_response=["apple", "price", "$"],
        description="Agent should call get_fruit_price for direct query"
    ),
    TestCase(
        name="recall_memory",
        messages=[
            "My favourite color is blue",  # First save something
            "What is my favourite color?"   # Then recall it
        ],
        expected_tools=[["save_memory"], ["recall_memory"]],
        expected_in_response=["blue"],
        description="Agent should recall previously saved information"
    ),
    TestCase(
        name="multi_step_reasoning",
        messages=[
            "My favourite fruit is banana",
            "What is the price of my favourite fruit?"
        ],
        expected_tools=[
            ["save_memory"],
            ["recall_memory", "get_fruit_price"]  # Should use both
        ],
        expected_in_response=["banana", "price", "$"],
        description="Agent should recall favourite fruit then get its price"
    ),
]


@dataclass
class EvalResult:
    test_name: str
    passed: bool
    message: str
    actual_tools: list[str]
    actual_response: str
    latency_ms: float
    trace_id: Optional[str] = None


async def call_agent(message: str, thread_id: str = "eval") -> dict:
    """Call the agent API and return response with timing."""
    async with httpx.AsyncClient(timeout=60.0) as client:
        import time
        start = time.perf_counter()
        response = await client.post(
            AGENT_URL,
            json={"message": message, "thread_id": thread_id}
        )
        latency_ms = (time.perf_counter() - start) * 1000
        
        response.raise_for_status()
        data = response.json()
        data["latency_ms"] = latency_ms
        return data


def extract_tool_names(tool_usage: list) -> list[str]:
    """Extract tool names from the tool_usage response."""
    tools = []
    for tool_calls in tool_usage:
        if isinstance(tool_calls, list):
            for call in tool_calls:
                if isinstance(call, dict) and "name" in call:
                    tools.append(call["name"])
    return tools


async def run_test_case(test: TestCase) -> list[EvalResult]:
    """Run a single test case (may have multiple messages)."""
    results = []
    thread_id = f"eval-{test.name}-{asyncio.get_event_loop().time()}"
    
    with tracer.start_as_current_span(f"eval:{test.name}") as span:
        span.set_attribute("test.name", test.name)
        span.set_attribute("test.description", test.description)
        
        for i, message in enumerate(test.messages):
            with tracer.start_as_current_span(f"message:{i}") as msg_span:
                try:
                    response = await call_agent(message, thread_id)
                    
                    actual_tools = extract_tool_names(response.get("tool_usage", []))
                    actual_response = response.get("response", "").lower()
                    latency = response.get("latency_ms", 0)
                    
                    # Check tool usage
                    expected = set(test.expected_tools[i]) if i < len(test.expected_tools) else set()
                    actual = set(actual_tools)
                    tools_match = expected.issubset(actual)  # Expected tools should be present
                    
                    # Check response content (only for last message)
                    response_valid = True
                    if i == len(test.messages) - 1:
                        response_valid = any(
                            exp.lower() in actual_response 
                            for exp in test.expected_in_response
                        )
                    
                    passed = tools_match and response_valid
                    
                    msg_span.set_attribute("eval.passed", passed)
                    msg_span.set_attribute("eval.tools_expected", list(expected))
                    msg_span.set_attribute("eval.tools_actual", actual_tools)
                    msg_span.set_attribute("eval.latency_ms", latency)
                    
                    result = EvalResult(
                        test_name=f"{test.name}[{i}]",
                        passed=passed,
                        message=f"Tools: {actual_tools}, Response valid: {response_valid}",
                        actual_tools=actual_tools,
                        actual_response=response.get("response", "")[:200],
                        latency_ms=latency,
                        trace_id=format(span.get_span_context().trace_id, '032x')
                    )
                    results.append(result)
                    
                except Exception as e:
                    results.append(EvalResult(
                        test_name=f"{test.name}[{i}]",
                        passed=False,
                        message=f"Error: {str(e)}",
                        actual_tools=[],
                        actual_response="",
                        latency_ms=0
                    ))
    
    return results


async def run_evaluation():
    """Run all happy path tests."""
    print("=" * 60)
    print("🧪 HAPPY PATH EVALUATION")
    print("=" * 60)
    
    all_results = []
    
    for test in HAPPY_PATH_TESTS:
        print(f"\n▶ Running: {test.name}")
        print(f"  {test.description}")
        
        results = await run_test_case(test)
        all_results.extend(results)
        
        for result in results:
            status = "✅ PASS" if result.passed else "❌ FAIL"
            print(f"  {status} {result.test_name}")
            print(f"    Tools: {result.actual_tools}")
            print(f"    Latency: {result.latency_ms:.0f}ms")
            if not result.passed:
                print(f"    Details: {result.message}")
                print(f"    Response: {result.actual_response[:100]}...")
    
    # Summary
    passed = sum(1 for r in all_results if r.passed)
    total = len(all_results)
    
    print("\n" + "=" * 60)
    print(f"📊 SUMMARY: {passed}/{total} tests passed ({100*passed/total:.0f}%)")
    print("=" * 60)
    
    # Latency stats
    latencies = [r.latency_ms for r in all_results if r.latency_ms > 0]
    if latencies:
        print(f"⏱  Latency: avg={sum(latencies)/len(latencies):.0f}ms, "
              f"min={min(latencies):.0f}ms, max={max(latencies):.0f}ms")
    
    return all_results


if __name__ == "__main__":
    asyncio.run(run_evaluation())