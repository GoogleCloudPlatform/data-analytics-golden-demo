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
# This module contains a curated and complete dictionary of sample prompts for the Data Beans Agent demo.
# Prompts are categorized and include explanations to help users understand the agent's capabilities.
# The structure supports multi-line prompts, explanations, and follow-up questions.

PROMPTS_BY_CATEGORY = {
    "AI Generate Bool": [
        {
            "prompt": "Which products contain coffee?",
            "explanation": "Demonstrates semantic text search on a column to filter rows based on meaning.",
            "follow_ups": [
                "Just show me the names."
            ]
        },
        {
            "prompt": "Do any product images have latte art?",
            "explanation": "Shows how the agent can analyze image content to answer questions.",
            "follow_ups": []
        },
        {
            "prompt": "Do any product category images have drinks that look chilly?",
            "explanation": "Shows how the agent can analyze image content to answer questions based on abstract concepts.",
            "follow_ups": []
        }
    ],
    "AI Forecast": [
        {
            "prompt": "For The Daily Grind truck will we run out of any ingredients in the next 2 hours?",
            "explanation": "A high-level business question that triggers a multi-series forecast to find potential stockouts.",
            "follow_ups": []
        },
        {
            "prompt": "For truck 10 forecast the ingredients for the next 2 hours.",
            "explanation": "Initiates a multi-series forecast, predicting future values for multiple ingredients on a specific truck.",
            "follow_ups": [
                "Will I run out (hit zero) for any ingredients?",
                "Which ingredients should I restock first?",
                "Show me the ingredients names."
            ]
        },
        {
            "prompt": "Forecast the number of people walking by the truck Mocha Mover for the next 2 hours.",
            "explanation": "Shows a single-series forecast for non-inventory data, like foot traffic.",
            "follow_ups": [
                "What is the peak time for people walking by?"
            ]
        },
        {
            "prompt": "Predict the grinder motor RPM for machine 1 for the next 3 hours. Will it fall below a critical threshold of 1500?",
            "explanation": "An example of predictive maintenance, forecasting sensor data to anticipate potential issues.",
            "follow_ups": []
        }
    ],
    "BigQuery: Vector Search": [
        {
            "prompt": "How much did the customer Gale buy? Ask me if you find more than one customer to select the correct one.",
            "explanation": "Demonstrates finding a customer using vector search and asking the agent to prompt the user for clarification.",
            "follow_ups": [
                "How much did Gale spend on Ciber brews?",
                "Can you look up the products that are related to coffee and see how much Gale spent?"
            ]
        },
        {
            "prompt": "Did the customer Guacharaca buy any Cyber Brews?",
            "explanation": "Demonstrates fixing typos in both customer names and product names to find the correct records before querying.",
            "follow_ups": [
                "How much did they spend?",
            ]
        },
        {
            "prompt": "How much in sales did I do for Latees for July 2025?",
            "explanation": "Shows how the agent can correct a misspelled product name ('Latees' -> 'Latte') before executing an NL2SQL query.",
            "follow_ups": [
                "Show me the SQL."
            ]
        }
    ],
    "BigQuery: NL2SQL": [
        {
            "prompt": "What is the total revenue for each product category for the current year up to now?",
            "explanation": "A standard natural language query that requires joining multiple tables and performing an aggregation.",
            "follow_ups": []
        },
        {
            "prompt": "Show me the top 5 customers by their total spend for all historical data up to the current moment.",
            "explanation": "A ranking query that sorts and limits results based on a user's question.",
            "follow_ups": []
        },
        {
            "prompt": "Which ingredient had the lowest average current quantity value across all trucks yesterday, excluding replenishment events?",
            "explanation": "A complex NL2SQL query requiring filtering, joins, aggregation, and ordering.",
            "follow_ups": []
        },
        {
            "prompt": "What is the total number of taxi trips for each borough for the most recent month available in the data?",
            "explanation": "NL2SQL on a different dataset (nyc_taxi), requiring the agent to find the latest month in the data.",
            "follow_ups": []
        },
        {
            "prompt": "Show me the average fare amount for each payment type, for the latest full year available in the dataset.",
            "explanation": "Another example on the taxi dataset that requires identifying the latest full year of data before aggregating.",
            "follow_ups": []
        }
    ],
    "Business Glossary": [
        {
            "prompt": "List all available business glossaries.",
            "explanation": "Shows how to discover and list top-level governance assets like glossaries.",
            "follow_ups": []
        },
        {
            "prompt": "Create a new business glossary called 'My New Glossary'.",
            "explanation": "Demonstrates the agent's ability to create new data governance resources.",
            "follow_ups": []
        },
        {
            "prompt": "Get details for the business glossary agentic beans raw.",
            "explanation": "Shows how to retrieve specific information about a known glossary.",
            "follow_ups": []
        },
        {
            "prompt": "Delete the business glossary My New Glossary.",
            "explanation": "Demonstrates the agent's ability to remove data governance resources.",
            "follow_ups": []
        },
        {
            "prompt": "List all categories in glossary 'agentic-beans-raw'.",
            "explanation": "Shows how to discover categories within a specific glossary.",
            "follow_ups": []
        },
        {
            "prompt": "In glossary 'agentic-beans-raw', create a new category named 'Data Quality Metrics'",
            "explanation": "Demonstrates creating a new category within an existing glossary.",
            "follow_ups": []
        },
        {
            "prompt": "Show me the categories.",
            "explanation": "A simple prompt to list categories, often used before a follow-up action.",
            "follow_ups": [
                "Delete the first one."
            ]
        },
        {
            "prompt": "List all terms in glossary agentic beans raw.",
            "explanation": "Shows how to list all business terms within an entire glossary.",
            "follow_ups": []
        },
        {
            "prompt": "Create a new term in glossary 'agentic-beans-raw' called 'Demo Term', with ID 'demo-term', and description 'A test term'.",
            "explanation": "Shows the agent's capability to create a specific business term within a category.",
            "follow_ups": []
        },
        {
            "prompt": "Update the term 'Foot Traffic' in glossary 'agentic-beans-raw'. Change its description to 'The number of people walking by a coffee truck'.",
            "explanation": "Demonstrates how the agent can modify existing glossary terms.",
            "follow_ups": []
        }
    ],
    "Data Engineering": [
        {
            "prompt": 'Create a pipeline named "Taxi Pipeline 01" that makes the field "borough" uppercase in the location table and saves it to a new table named "location_uppercase".',
            "explanation": "Demonstrates creating a complete data transformation pipeline from a single natural language prompt.",
            "follow_ups": []
        },
        {
            "prompt": """Create a new BigQuery pipeline named 'Sales Data Pipeline 01'. 
I want to generate a denormalized sales table within the agentic_beans_curated dataset. 
This table should combine data from order_header, order_detail, customer, product, and truck.""",
            "explanation": "Shows the creation of a more complex pipeline that involves joining multiple tables.",
            "follow_ups": [
                "Modify the BigQuery pipeline named 'Sales Data Pipeline 01' to make the truck name uppercase."
            ]
        }
    ],
    "Data Engineering - Autonomous": [
        {
            "prompt": """Autonomously correct this dataform pipeline:
repository_name: "agentic-beans-repo"
workspace_name: "telemetry-coffee-machine-auto"
data_quality_scan_name: "telemetry-coffee-machine-staging-load-dq"
""",
            "explanation": "Triggers the autonomous agent to diagnose data quality failures and automatically generate and apply a code fix to the pipeline.",
            "follow_ups": []
        },
        {
            "prompt": "reset demo",
            "explanation": "A utility command to reset the autonomous data engineering demo environment to its original, broken state.",
            "follow_ups": []
        }
    ],
    "Dataplex: Data Catalog Search": [
        {
            "prompt": "What tables have customer information?",
            "explanation": "A simple natural language search across the data catalog to find relevant data assets.",
            "follow_ups": []
        },
        {
            "prompt": "What pub/sub do I have?",
            "explanation": "Shows that the data catalog can find more than just BigQuery tables, including messaging topics.",
            "follow_ups": []
        }
    ],
    "Dataplex: Data Discovery": [
        {
            "prompt": "What data discovery exist on my tables in my data bucket?",
            "explanation": "Use this to discover scans run on GCS buckets to make unstructured data queryable.",
            "follow_ups": []
        }
    ],
    "Dataplex: Data Insights": [
        {
            "prompt": "What data insights exist on my tables in my raw dataset?",
            "explanation": "Use this to see auto-generated documentation and statistical insights for your BigQuery datasets.",
            "follow_ups": []
        }
    ],
    "Dataplex: Data Profiles": [
        {
            "prompt": """Create a data profile scan:
data_profile_scan_name: "product-category-01"
data_profile_display_name: "Product Category 01"
bigquery_dataset_name: "agentic_beans_curated"
bigquery_table_name: "product_category"
""",
            "explanation": "Shows how to create a data profiling scan by providing all necessary parameters in a structured, multi-line prompt.",
            "follow_ups": []
        },
        {
            "prompt": """Create a scan workflow:
data_profile_scan_name: "truck-menu-01"
data_profile_display_name: "Truck Menu 01"
bigquery_dataset_name: "agentic beans curated"
bigquery_table_name: "truck menu"
""",
            "explanation": "This special prompt demonstrates various advanced agentic workflows for creating a scan, prompting the user to choose a method.",
            "follow_ups": []
        },
        {
            "prompt": "Show me the data profile summary on the product category table in my curated dataset.",
            "explanation": "Allows you to view the results and summary of a completed data profiling scan.",
            "follow_ups": []
        }
    ],
    "Dataplex: Data Quality": [
        {
            "prompt": "What data quality scans exist on my tables in my raw dataset?",
            "explanation": "Discover existing data quality scans associated with a specific dataset.",
            "follow_ups": []
        },
        {
            "prompt": "Show me a summary of my data quality on the product category table in the curated dataset.",
            "explanation": "View the results of a data quality scan, showing pass/fail rates for data validation rules.",
            "follow_ups": []
        },
        {
            "prompt": "Delete the data quality scan on the product category table in the curated dataset.",
            "explanation": "Demonstrates the agent's ability to manage and clean up Dataplex resources.",
            "follow_ups": []
        }
    ],
    "Knowledge Engine": [
        {
            "prompt": "What knowledge engine exist on my raw dataset?",
            "explanation": "Use this to discover existing knowledge scans that have analyzed your data for relationships and insights.",
            "follow_ups": [
                "Show me the first scan."
            ]
        },
        {
            "prompt": "Create an knowledge engine scan on my raw dataset and name it 'demo-scan-raw-01'.",
            "explanation": "Shows how to create and run a Knowledge Engine scan to generate metadata insights.",
            "follow_ups": [
                "Show me the scan summary."
            ]
        }
    ],
    "Knowledge Engine Business Glossary": [
        {
            "prompt": "Create a business glossary on my agentic raw dataset based upon my knowledge scan.",
            "explanation": "A powerful workflow where the agent uses a Knowledge Engine scan's output to auto-generate a complete business glossary.",
            "follow_ups": []
        }
    ]
}

def get_prompt_categories() -> list[str]:
    """
    Returns a list of the available prompt categories. This tool should be called when a user
    asks for sample prompts or examples.
    """
    return list(PROMPTS_BY_CATEGORY.keys())

def get_prompts_for_category(category_name: str) -> str:
    """
    Formats and returns a string of prompts for a given category, including explanations and follow-ups.
    This tool should be called after the user has selected a category.

    Args:
        category_name: The name of the category the user wants to see prompts for.

    Returns:
        A formatted string of prompts or a helpful error message if the category is not found.
    """
    # Use case-insensitive matching for a better user experience
    selected_category = None
    for key in PROMPTS_BY_CATEGORY:
        if key.lower() == category_name.lower().strip():
            selected_category = key
            break

    if not selected_category:
        available_categories = ", ".join(get_prompt_categories())
        return f"Sorry, I could not find the category '{category_name}'. Please choose from one of the available categories: {available_categories}"

    # Build a formatted string for the response
    response_lines = [f"Here are some sample prompts for the '{selected_category}' category:"]
    
    for item in PROMPTS_BY_CATEGORY[selected_category]:
        # For multi-line prompts, add an extra newline for better separation
        response_lines.append(f"\n- Prompt:")
        response_lines.append(f"{item['prompt']}")
        
        if item.get('explanation'):
            response_lines.append(f"  - (Explanation) {item['explanation']}")
        if item['follow_ups']:
            for followup in item['follow_ups']:
                response_lines.append(f"  - (Follow-up) {followup}")
    
    return "\n".join(response_lines)