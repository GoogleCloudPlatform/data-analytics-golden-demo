# pip install google-search-results
# python events.py

from serpapi import GoogleSearch
from dotenv import load_dotenv
import os

load_dotenv()

google_events_params = {
  "engine": "google_events",
  "q": "Events in New York City",
  "hl": "en",
  "gl": "us",
  "api_key": os.getenv("EVENTS_API_KEY"),
  'start': 0
}

# https://serpapi.com/blog/scrape-google-events-results-with-python/
# https://serpapi.com/google-events-api


events_for_llm = []
events_for_llm.append("[")

while True:
    search = GoogleSearch(google_events_params)
    event_search_results = search.get_dict()
    if 'error' in event_search_results:
        break

    for item in event_search_results["events_results"]:
        try:
            events_for_llm.append('{ "title":"' + item['title'] + '", "address":"' + item['address'][0] + '", "description":"' + item['description'] + '" }')
        except Exception as error: 
            print("Skipping (error): ", error)
    
    google_events_params['start'] += 10

    if google_events_params['start'] > 30:
        break # only do 30 for now so our prompt is not too large

events_for_llm.append("]")

for result in events_for_llm:
    print(result)
      