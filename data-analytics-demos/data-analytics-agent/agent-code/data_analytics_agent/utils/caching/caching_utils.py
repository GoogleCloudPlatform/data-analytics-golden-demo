import time
import functools
import logging

logger = logging.getLogger(__name__)

def timed_cache(seconds: int):
    """
    A decorator that caches the result of the async function for a specified duration.
    The cache is specific to the decorated function.
    """
    # This cache is specific to each function instance that uses this decorator
    _cache = {"data": None, "timestamp": 0} 

    def decorator(func):
        @functools.wraps(func)
        async def wrapper(*args, **kwargs): # Changed to async def
            current_time = time.time()
            # Check if cached data exists and is still fresh
            if _cache["data"] is not None and (current_time - _cache["timestamp"]) < seconds:
                logger.debug(f"Returning cached result for {func.__name__} from data_analytics_agent.caching_utils.")
                return _cache["data"]
            else:
                # Cache is stale or empty, execute the original async function
                result = await func(*args, **kwargs) # Added await
                # Store the new result and current time in the cache
                _cache["data"] = result
                _cache["timestamp"] = current_time
                logger.debug(f"Caching new result for {func.__name__} in data_analytics_agent.caching_utils.")
                return result
        return wrapper
    return decorator