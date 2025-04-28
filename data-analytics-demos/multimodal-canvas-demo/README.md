1. Deploy the notebook
    - You will need to create a storage account by hand (location=US)
    - You will need to create an external connection by hand (location=US, type=BigLake/Vertex, name=vertex-ai)
        - You will need to grant Vertex AI User role to the service principal on the external connection)

2. Open the Cymbal Pets Multimodal Search.dc.ipynb with a text editor
    - Search for "data-demo-n25" and replace with your project id