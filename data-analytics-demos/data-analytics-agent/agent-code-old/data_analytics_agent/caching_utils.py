####################################################################################
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####################################################################################
import time
import functools
import logging

logger = logging.getLogger(__name__)

def timed_cache(seconds: int):
    """
    A decorator that caches the result of the function for a specified duration.
    The cache is specific to the decorated function.
    """
    _cache = {"data": None, "timestamp": 0}

    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            current_time = time.time()
            # Check if cached data exists and is still fresh
            if _cache["data"] is not None and (current_time - _cache["timestamp"]) < seconds:
                logger.debug(f"Returning cached result for {func.__name__} from data_analytics_agent.caching_utils.")
                return _cache["data"]
            else:
                # Cache is stale or empty, execute the original function
                result = func(*args, **kwargs)
                # Store the new result and current time in the cache
                _cache["data"] = result
                _cache["timestamp"] = current_time
                logger.debug(f"Caching new result for {func.__name__} in data_analytics_agent.caching_utils.")
                return result
        return wrapper
    return decorator