import os
import logging
from mcp.server.fastmcp import FastMCP

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

from ddgs import DDGS


OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318/v1/traces")

# --- Telemetry setup ---
resource = Resource(attributes={"service.name": "mcp-server"})
trace.set_tracer_provider(TracerProvider(resource=resource))
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTEL_ENDPOINT))
)
tracer = trace.get_tracer(__name__)

mcp = FastMCP("Fruit_Prices", host="0.0.0.0", port=8000)


@mcp.tool()
async def get_fruit_price(fruit_name: str) -> str:
    """Get price with the fruit_name passed in as parameter."""
    with tracer.start_as_current_span("get_fruit_price", attributes={"fruit.name": fruit_name}):
        logging.log(logging.INFO, f"Received request to generate price of {fruit_name}")
        return f"Price for {fruit_name} is $2.99 per kg"

@mcp.tool()
async def web_search(query: str) -> str:
    """Search the web for information based on a query and return top 20 results."""
    with tracer.start_as_current_span("web_search", attributes={"query": query}):
        logging.log(logging.INFO, f"Searching web for: {query}")
        try:
            results = DDGS().text(query, max_results=20)
            if not results:
                return "No results found."
            
            # Format the results into a readable string for the agent
            formatted_results = []
            for i, r in enumerate(results, 1):
                formatted_results.append(f"{i}. {r.get('title', 'No Title')}\nURL: {r.get('href', 'No URL')}\nSnippet: {r.get('body', 'No Snippet')}\n")
            
            return "\n".join(formatted_results)
        except Exception as e:
            logging.error(f"Web search failed: {e}")
            return f"Error performing web search: {str(e)}"
        
if __name__ == "__main__":
    mcp.run(transport="sse")
