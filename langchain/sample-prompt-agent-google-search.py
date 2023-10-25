####################################################################################
# Copyright 2022 Google LLC
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

# Author:  Adam Paternostro
# Summary: Use Google Search along with text-bison for Langchan example

# To setup your environemtn
# python3 -m venv .venv
# source .venv/bin/activate
# pip install --only-binary :all: greenlet
# pip install langchain pip install langchain==0.0.307
# pip install google-cloud-aiplatform 
# pip install streamlit==1.27.2
# pip install python-dotenv==1.0.0
# pip install google-api-python-client==2.100.0
# pip install numexpr==2.8.6
# pip install youtube_search==2.1.2
# run it: python sample-prompt-agent-google-search.py
# run in browers: streamlit run sample-prompt-agent-google-search.py
# deactivate

import json
import langchain
from langchain.llms import VertexAI
from langchain.agents import load_tools, initialize_agent, AgentType
from langchain.callbacks import StreamlitCallbackHandler
from langchain.tools import Tool
from langchain.tools import YouTubeSearchTool
from langchain.utilities import GoogleSearchAPIWrapper
from langchain.chains import LLMMathChain
from dotenv import load_dotenv
import streamlit as st
import os

load_dotenv()

st.set_page_config(page_title="Google Cloud - LLMs w/Langchain", page_icon="⭐")
st.title = "Langchain Demo"

llm = VertexAI(
    model_name="text-bison@001",
    max_output_tokens=1024,
    temperature=0.25,
    top_p=0,
    top_k=1,
    verbose=True,
)

#llm_math_chain = LLMMathChain.from_llm(llm)
#llm_math = LLMMathChain.from_llm(llm, verbose=True)

# https://python.langchain.com/docs/integrations/tools/google_search
# Create 2 keys
# Enable search in the console: https://console.cloud.google.com/apis/library/customsearch.googleapis.com
#search = GoogleSearchAPIWrapper(google_api_key=google_api_key,google_cse_id=google_cse_id)
search = GoogleSearchAPIWrapper()

google_search_tool = Tool(
    name="Google Search",
    description="Search Google for recent results.",
    func=search.run,
)

youtube_search_tool = YouTubeSearchTool()

tools = load_tools(["llm-math"], llm=llm)

tools.append(google_search_tool)
tools.append(youtube_search_tool)

agent = initialize_agent (tools=tools, llm=llm, agent=AgentType.ZERO_SHOT_REACT_DESCRIPTION, verbose=True)

if prompt := st.chat_input():
    st.chat_message("user").write(prompt)
    with st.chat_message("assistant"):
        st.write("Thinking...")
        st_callback = StreamlitCallbackHandler(st.container())
        response = agent.run(prompt, callbacks=[st_callback])
        st.write(response)