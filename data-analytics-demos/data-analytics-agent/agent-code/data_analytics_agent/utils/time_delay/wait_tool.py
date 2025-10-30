import asyncio 
import logging


logger = logging.getLogger(__name__)

async def wait_for_seconds(seconds: int) -> dict:
    """
    Instructs the agent's execution environment to pause for the specified number of seconds.
    This tool uses asyncio.sleep, which is non-blocking for the event loop.

    Args:
        seconds (int): The number of seconds to wait.

    Returns:
        dict: A dictionary indicating the wait was initiated.
    """
    messages = [f"Agent is requesting a pause for {seconds} seconds (non-blocking)."]
    logger.info(messages[0])

    await asyncio.sleep(seconds) 

    return {
        "status": "success",
        "tool_name": "wait_for_seconds",
        "query": None,
        "messages": messages,
        "results": {"waited_for_seconds": seconds}
    }