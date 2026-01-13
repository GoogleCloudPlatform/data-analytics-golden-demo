#!/bin/bash

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

# Deploys the Rideshare Plus App Engine website

# Hardcoded for now (until more regions are activated)
PROJECT_ID="{{ params.project_id }}"
RIDESHARE_RAW_BUCKET="{{ params.rideshare_raw_bucket }}"

##########################################################################################
# https://www.pexels.com/license/
# All photos and videos on Pexels are free to use.
##########################################################################################


cd /home/airflow/gcs/data
mkdir images
cd images

# Download and upload the Pexels image in the doc script
curl -L "https://images.pexels.com/photos/1008155/pexels-photo-1008155.jpeg"  --output pexels-photo-1008155.jpeg
gcloud storage cp pexels-photo-1008155.jpeg "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-1008155.jpeg" --custom-metadata="location_id=1"

# Copy public domain images
gcloud storage cp gs://data-analytics-golden-demo/rideshare-lakehouse-raw-bucket/rideshare_images/* gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/


# Copy public domain images from the public storage account
# curl -L "https://images.pexels.com/photos/1486222/pexels-photo-1486222.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-1.jpeg
# curl -L "https://images.pexels.com/photos/1796505/pexels-photo-1796505.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-2.jpeg
# curl -L "https://images.pexels.com/photos/1389339/pexels-photo-1389339.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-3.jpeg
# curl -L "https://images.pexels.com/photos/1402790/pexels-photo-1402790.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-4.jpeg
# curl -L "https://images.pexels.com/photos/2422588/pexels-photo-2422588.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-5.jpeg
# curl -L "https://images.pexels.com/photos/1770775/pexels-photo-1770775.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-6.jpeg
# curl -L "https://images.pexels.com/photos/1634279/pexels-photo-1634279.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-7.jpeg
# curl -L "https://images.pexels.com/photos/1737957/pexels-photo-1737957.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-8.jpeg
# curl -L "https://images.pexels.com/photos/2260784/pexels-photo-2260784.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-9.jpeg
# curl -L "https://images.pexels.com/photos/1634272/pexels-photo-1634272.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-10.jpeg
# curl -L "https://images.pexels.com/photos/1054417/pexels-photo-1054417.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-11.jpeg
# curl -L "https://images.pexels.com/photos/1634276/pexels-photo-1634276.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-12.jpeg
# curl -L "https://images.pexels.com/photos/2777932/pexels-photo-2777932.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-13.jpeg
# curl -L "https://images.pexels.com/photos/1634278/pexels-photo-1634278.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-14.jpeg
# curl -L "https://images.pexels.com/photos/2069903/pexels-photo-2069903.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-15.jpeg
# curl -L "https://images.pexels.com/photos/1058275/pexels-photo-1058275.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-16.jpeg
# curl -L "https://images.pexels.com/photos/162024/park-new-york-city-nyc-manhattan-162024.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-17.jpeg
# curl -L "https://images.pexels.com/photos/2419375/pexels-photo-2419375.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-18.jpeg
# curl -L "https://images.pexels.com/photos/1634275/pexels-photo-1634275.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-19.jpeg
# curl -L "https://images.pexels.com/photos/1862047/pexels-photo-1862047.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-20.jpeg
# curl -L "https://images.pexels.com/photos/296492/pexels-photo-296492.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-21.jpeg
# curl -L "https://images.pexels.com/photos/3544024/pexels-photo-3544024.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-22.jpeg
# curl -L "https://images.pexels.com/photos/402898/pexels-photo-402898.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-23.jpeg
# curl -L "https://images.pexels.com/photos/4457045/pexels-photo-4457045.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-24.jpeg
# curl -L "https://images.pexels.com/photos/2166807/pexels-photo-2166807.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-25.jpeg
# curl -L "https://images.pexels.com/photos/3031255/pexels-photo-3031255.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-26.jpeg
# curl -L "https://images.pexels.com/photos/3230150/pexels-photo-3230150.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-27.jpeg
# curl -L "https://images.pexels.com/photos/2174715/pexels-photo-2174715.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-28.jpeg
# curl -L "https://images.pexels.com/photos/15327231/pexels-photo-15327231.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-29.jpeg
# curl -L "https://images.pexels.com/photos/3031209/pexels-photo-3031209.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-30.jpeg
# curl -L "https://images.pexels.com/photos/15327177/pexels-photo-15327177.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-31.jpeg
# curl -L "https://images.pexels.com/photos/15327222/pexels-photo-15327222.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-32.jpeg
# curl -L "https://images.pexels.com/photos/12564036/pexels-photo-12564036.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-33.jpeg
# curl -L "https://images.pexels.com/photos/332208/pexels-photo-332208.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-34.jpeg
# curl -L "https://images.pexels.com/photos/14344443/pexels-photo-14344443.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-35.jpeg
# curl -L "https://images.pexels.com/photos/10025314/pexels-photo-10025314.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-36.jpeg
# curl -L "https://images.pexels.com/photos/12373196/pexels-photo-12373196.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-37.jpeg
# curl -L "https://images.pexels.com/photos/5847385/pexels-photo-5847385.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-38.jpeg
# curl -L "https://images.pexels.com/photos/6457091/pexels-photo-6457091.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-39.jpeg
# curl -L "https://images.pexels.com/photos/12223579/pexels-photo-12223579.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-40.jpeg
# curl -L "https://images.pexels.com/photos/4451745/pexels-photo-4451745.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-41.jpeg
# curl -L "https://images.pexels.com/photos/5845718/pexels-photo-5845718.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-42.jpeg
# curl -L "https://images.pexels.com/photos/5847394/pexels-photo-5847394.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-43.jpeg
# curl -L "https://images.pexels.com/photos/5669637/pexels-photo-5669637.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-44.jpeg
# curl -L "https://images.pexels.com/photos/12206305/pexels-photo-12206305.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-45.jpeg
# curl -L "https://images.pexels.com/photos/12229002/pexels-photo-12229002.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-46.jpeg
# curl -L "https://images.pexels.com/photos/859214/pexels-photo-859214.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-47.jpeg
# curl -L "https://images.pexels.com/photos/580117/pexels-photo-580117.png?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-48.jpeg
# curl -L "https://images.pexels.com/photos/5157713/pexels-photo-5157713.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-49.jpeg
# curl -L "https://images.pexels.com/photos/5847570/pexels-photo-5847570.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-50.jpeg
# curl -L "https://images.pexels.com/photos/9948846/pexels-photo-9948846.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-51.jpeg
# curl -L "https://images.pexels.com/photos/10086614/pexels-photo-10086614.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-52.jpeg
# curl -L "https://images.pexels.com/photos/14072803/pexels-photo-14072803.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-53.jpeg
# curl -L "https://images.pexels.com/photos/2438244/pexels-photo-2438244.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-54.jpeg
# curl -L "https://images.pexels.com/photos/5157232/pexels-photo-5157232.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-55.jpeg
# curl -L "https://images.pexels.com/photos/2326231/pexels-photo-2326231.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-56.jpeg
# curl -L "https://images.pexels.com/photos/5834954/pexels-photo-5834954.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-57.jpeg
# curl -L "https://images.pexels.com/photos/5834955/pexels-photo-5834955.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-58.jpeg
# curl -L "https://images.pexels.com/photos/5834919/pexels-photo-5834919.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-59.jpeg
# curl -L "https://images.pexels.com/photos/5835452/pexels-photo-5835452.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-60.jpeg
# curl -L "https://images.pexels.com/photos/9948837/pexels-photo-9948837.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-61.jpeg
# curl -L "https://images.pexels.com/photos/10086615/pexels-photo-10086615.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-62.jpeg
# curl -L "https://images.pexels.com/photos/10086616/pexels-photo-10086616.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-63.jpeg
# curl -L "https://images.pexels.com/photos/5999777/pexels-photo-5999777.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-64.jpeg
# curl -L "https://images.pexels.com/photos/10585386/pexels-photo-10585386.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-65.jpeg
# curl -L "https://images.pexels.com/photos/4509365/pexels-photo-4509365.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-66.jpeg
# curl -L "https://images.pexels.com/photos/6408235/pexels-photo-6408235.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-67.jpeg
# curl -L "https://images.pexels.com/photos/7213821/pexels-photo-7213821.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-68.jpeg
# curl -L "https://images.pexels.com/photos/7258774/pexels-photo-7258774.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-69.jpeg
# curl -L "https://images.pexels.com/photos/14094411/pexels-photo-14094411.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-70.jpeg
# curl -L "https://images.pexels.com/photos/13264450/pexels-photo-13264450.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-71.jpeg
# curl -L "https://images.pexels.com/photos/6283012/pexels-photo-6283012.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-72.jpeg
# curl -L "https://images.pexels.com/photos/14569842/pexels-photo-14569842.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-73.jpeg
# curl -L "https://images.pexels.com/photos/12729169/pexels-photo-12729169.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-74.jpeg
# curl -L "https://images.pexels.com/photos/13986928/pexels-photo-13986928.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-75.jpeg
# curl -L "https://images.pexels.com/photos/6219393/pexels-photo-6219393.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-76.jpeg
# curl -L "https://images.pexels.com/photos/5919995/pexels-photo-5919995.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-77.jpeg
# curl -L "https://images.pexels.com/photos/9403249/pexels-photo-9403249.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-78.jpeg
# curl -L "https://images.pexels.com/photos/9403233/pexels-photo-9403233.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-79.jpeg
# curl -L "https://images.pexels.com/photos/14094459/pexels-photo-14094459.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-80.jpeg
# curl -L "https://images.pexels.com/photos/12299042/pexels-photo-12299042.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-81.jpeg
# curl -L "https://images.pexels.com/photos/4078599/pexels-photo-4078599.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-82.jpeg
# curl -L "https://images.pexels.com/photos/5620129/pexels-photo-5620129.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-83.jpeg
# curl -L "https://images.pexels.com/photos/10259011/pexels-photo-10259011.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-84.jpeg
# curl -L "https://images.pexels.com/photos/10046153/pexels-photo-10046153.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-85.jpeg
# curl -L "https://images.pexels.com/photos/9283757/pexels-photo-9283757.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-86.jpeg
# curl -L "https://images.pexels.com/photos/11579270/pexels-photo-11579270.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-87.jpeg
# curl -L "https://images.pexels.com/photos/11250388/pexels-photo-11250388.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-88.jpeg
# curl -L "https://images.pexels.com/photos/9559782/pexels-photo-9559782.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-89.jpeg
# curl -L "https://images.pexels.com/photos/11247840/pexels-photo-11247840.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-90.jpeg
# curl -L "https://images.pexels.com/photos/11106635/pexels-photo-11106635.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-91.jpeg
# curl -L "https://images.pexels.com/photos/13067864/pexels-photo-13067864.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-92.jpeg
# curl -L "https://images.pexels.com/photos/14423060/pexels-photo-14423060.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-93.jpeg
# curl -L "https://images.pexels.com/photos/2438245/pexels-photo-2438245.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-94.jpeg
# curl -L "https://images.pexels.com/photos/4939717/pexels-photo-4939717.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-95.jpeg
# curl -L "https://images.pexels.com/photos/5306625/pexels-photo-5306625.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-96.jpeg
# curl -L "https://images.pexels.com/photos/4201122/pexels-photo-4201122.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-97.jpeg
# curl -L "https://images.pexels.com/photos/4148682/pexels-photo-4148682.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-98.jpeg
# curl -L "https://images.pexels.com/photos/3031258/pexels-photo-3031258.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-99.jpeg
# curl -L "https://images.pexels.com/photos/6189395/pexels-photo-6189395.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-100.jpeg
# curl -L "https://images.pexels.com/photos/5819163/pexels-photo-5819163.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-101.jpeg
# curl -L "https://images.pexels.com/photos/5821744/pexels-photo-5821744.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-102.jpeg
# curl -L "https://images.pexels.com/photos/5691353/pexels-photo-5691353.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-103.jpeg
# curl -L "https://images.pexels.com/photos/5499620/pexels-photo-5499620.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-104.jpeg
# curl -L "https://images.pexels.com/photos/5442197/pexels-photo-5442197.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-105.jpeg
# curl -L "https://images.pexels.com/photos/6437432/pexels-photo-6437432.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-106.jpeg
# curl -L "https://images.pexels.com/photos/5928130/pexels-photo-5928130.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-107.jpeg
# curl -L "https://images.pexels.com/photos/6457079/pexels-photo-6457079.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-108.jpeg
# curl -L "https://images.pexels.com/photos/7070933/pexels-photo-7070933.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-109.jpeg
# curl -L "https://images.pexels.com/photos/7465289/pexels-photo-7465289.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-110.jpeg
# curl -L "https://images.pexels.com/photos/7888180/pexels-photo-7888180.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-111.jpeg
# curl -L "https://images.pexels.com/photos/7165335/pexels-photo-7165335.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-112.jpeg
# curl -L "https://images.pexels.com/photos/10489707/pexels-photo-10489707.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-113.jpeg
# curl -L "https://images.pexels.com/photos/8975671/pexels-photo-8975671.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-114.jpeg
# curl -L "https://images.pexels.com/photos/10046151/pexels-photo-10046151.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-115.jpeg
# curl -L "https://images.pexels.com/photos/10107525/pexels-photo-10107525.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-116.jpeg
# curl -L "https://images.pexels.com/photos/10602526/pexels-photo-10602526.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-117.jpeg
# curl -L "https://images.pexels.com/photos/7730416/pexels-photo-7730416.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-118.jpeg
# curl -L "https://images.pexels.com/photos/12167728/pexels-photo-12167728.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-119.jpeg
# curl -L "https://images.pexels.com/photos/12303592/pexels-photo-12303592.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-120.jpeg
# curl -L "https://images.pexels.com/photos/13266053/pexels-photo-13266053.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-121.jpeg
# curl -L "https://images.pexels.com/photos/1486222/pexels-photo-1486222.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-122.jpeg
# curl -L "https://images.pexels.com/photos/1796505/pexels-photo-1796505.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-123.jpeg
# curl -L "https://images.pexels.com/photos/1389339/pexels-photo-1389339.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-124.jpeg
# curl -L "https://images.pexels.com/photos/1402790/pexels-photo-1402790.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-125.jpeg
# curl -L "https://images.pexels.com/photos/2422588/pexels-photo-2422588.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-126.jpeg
# curl -L "https://images.pexels.com/photos/1770775/pexels-photo-1770775.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-127.jpeg
# curl -L "https://images.pexels.com/photos/1634279/pexels-photo-1634279.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-128.jpeg
# curl -L "https://images.pexels.com/photos/1737957/pexels-photo-1737957.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-129.jpeg
# curl -L "https://images.pexels.com/photos/2260784/pexels-photo-2260784.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-130.jpeg
# curl -L "https://images.pexels.com/photos/1634272/pexels-photo-1634272.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-131.jpeg
# curl -L "https://images.pexels.com/photos/1054417/pexels-photo-1054417.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-132.jpeg
# curl -L "https://images.pexels.com/photos/1634276/pexels-photo-1634276.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-133.jpeg
# curl -L "https://images.pexels.com/photos/2777932/pexels-photo-2777932.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-134.jpeg
# curl -L "https://images.pexels.com/photos/1634278/pexels-photo-1634278.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-135.jpeg
# curl -L "https://images.pexels.com/photos/2069903/pexels-photo-2069903.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-136.jpeg
# curl -L "https://images.pexels.com/photos/1058275/pexels-photo-1058275.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-137.jpeg
# curl -L "https://images.pexels.com/photos/162024/park-new-york-city-nyc-manhattan-162024.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-138.jpeg
# curl -L "https://images.pexels.com/photos/2419375/pexels-photo-2419375.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-139.jpeg
# curl -L "https://images.pexels.com/photos/1634275/pexels-photo-1634275.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-140.jpeg
# curl -L "https://images.pexels.com/photos/1862047/pexels-photo-1862047.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-141.jpeg
# curl -L "https://images.pexels.com/photos/296492/pexels-photo-296492.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-142.jpeg
# curl -L "https://images.pexels.com/photos/3544024/pexels-photo-3544024.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-143.jpeg
# curl -L "https://images.pexels.com/photos/402898/pexels-photo-402898.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-144.jpeg
# curl -L "https://images.pexels.com/photos/4457045/pexels-photo-4457045.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-145.jpeg
# curl -L "https://images.pexels.com/photos/2166807/pexels-photo-2166807.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-146.jpeg
# curl -L "https://images.pexels.com/photos/3031255/pexels-photo-3031255.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-147.jpeg
# curl -L "https://images.pexels.com/photos/3230150/pexels-photo-3230150.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-148.jpeg
# curl -L "https://images.pexels.com/photos/2174715/pexels-photo-2174715.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-149.jpeg
# curl -L "https://images.pexels.com/photos/15327231/pexels-photo-15327231.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-150.jpeg
# curl -L "https://images.pexels.com/photos/3031209/pexels-photo-3031209.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-151.jpeg
# curl -L "https://images.pexels.com/photos/15327177/pexels-photo-15327177.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-152.jpeg
# curl -L "https://images.pexels.com/photos/15327222/pexels-photo-15327222.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-153.jpeg
# curl -L "https://images.pexels.com/photos/12564036/pexels-photo-12564036.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-154.jpeg
# curl -L "https://images.pexels.com/photos/332208/pexels-photo-332208.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-155.jpeg
# curl -L "https://images.pexels.com/photos/14344443/pexels-photo-14344443.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-156.jpeg
# curl -L "https://images.pexels.com/photos/10025314/pexels-photo-10025314.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-157.jpeg
# curl -L "https://images.pexels.com/photos/12373196/pexels-photo-12373196.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-158.jpeg
# curl -L "https://images.pexels.com/photos/5847385/pexels-photo-5847385.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-159.jpeg
# curl -L "https://images.pexels.com/photos/6457091/pexels-photo-6457091.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-160.jpeg
# curl -L "https://images.pexels.com/photos/12223579/pexels-photo-12223579.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-161.jpeg
# curl -L "https://images.pexels.com/photos/4451745/pexels-photo-4451745.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-162.jpeg
# curl -L "https://images.pexels.com/photos/5845718/pexels-photo-5845718.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-163.jpeg
# curl -L "https://images.pexels.com/photos/5847394/pexels-photo-5847394.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-164.jpeg
# curl -L "https://images.pexels.com/photos/5669637/pexels-photo-5669637.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-165.jpeg
# curl -L "https://images.pexels.com/photos/12206305/pexels-photo-12206305.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-166.jpeg
# curl -L "https://images.pexels.com/photos/12229002/pexels-photo-12229002.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-167.jpeg
# curl -L "https://images.pexels.com/photos/859214/pexels-photo-859214.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-168.jpeg
# curl -L "https://images.pexels.com/photos/580117/pexels-photo-580117.png?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-169.jpeg
# curl -L "https://images.pexels.com/photos/5157713/pexels-photo-5157713.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-170.jpeg
# curl -L "https://images.pexels.com/photos/5847570/pexels-photo-5847570.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-171.jpeg
# curl -L "https://images.pexels.com/photos/9948846/pexels-photo-9948846.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-172.jpeg
# curl -L "https://images.pexels.com/photos/10086614/pexels-photo-10086614.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-173.jpeg
# curl -L "https://images.pexels.com/photos/14072803/pexels-photo-14072803.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-174.jpeg
# curl -L "https://images.pexels.com/photos/2438244/pexels-photo-2438244.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-175.jpeg
# curl -L "https://images.pexels.com/photos/5157232/pexels-photo-5157232.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-176.jpeg
# curl -L "https://images.pexels.com/photos/2326231/pexels-photo-2326231.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-177.jpeg
# curl -L "https://images.pexels.com/photos/5834954/pexels-photo-5834954.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-178.jpeg
# curl -L "https://images.pexels.com/photos/5834955/pexels-photo-5834955.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-179.jpeg
# curl -L "https://images.pexels.com/photos/5834919/pexels-photo-5834919.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-180.jpeg
# curl -L "https://images.pexels.com/photos/5835452/pexels-photo-5835452.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-181.jpeg
# curl -L "https://images.pexels.com/photos/9948837/pexels-photo-9948837.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-182.jpeg
# curl -L "https://images.pexels.com/photos/10086615/pexels-photo-10086615.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-183.jpeg
# curl -L "https://images.pexels.com/photos/10086616/pexels-photo-10086616.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-184.jpeg
# curl -L "https://images.pexels.com/photos/5999777/pexels-photo-5999777.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-185.jpeg
# curl -L "https://images.pexels.com/photos/10585386/pexels-photo-10585386.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-186.jpeg
# curl -L "https://images.pexels.com/photos/4509365/pexels-photo-4509365.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-187.jpeg
# curl -L "https://images.pexels.com/photos/6408235/pexels-photo-6408235.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-188.jpeg
# curl -L "https://images.pexels.com/photos/7213821/pexels-photo-7213821.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-189.jpeg
# curl -L "https://images.pexels.com/photos/7258774/pexels-photo-7258774.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-190.jpeg
# curl -L "https://images.pexels.com/photos/14094411/pexels-photo-14094411.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-191.jpeg
# curl -L "https://images.pexels.com/photos/13264450/pexels-photo-13264450.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-192.jpeg
# curl -L "https://images.pexels.com/photos/6283012/pexels-photo-6283012.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-193.jpeg
# curl -L "https://images.pexels.com/photos/14569842/pexels-photo-14569842.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-194.jpeg
# curl -L "https://images.pexels.com/photos/12729169/pexels-photo-12729169.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-195.jpeg
# curl -L "https://images.pexels.com/photos/13986928/pexels-photo-13986928.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-196.jpeg
# curl -L "https://images.pexels.com/photos/6219393/pexels-photo-6219393.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-197.jpeg
# curl -L "https://images.pexels.com/photos/5919995/pexels-photo-5919995.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-198.jpeg
# curl -L "https://images.pexels.com/photos/9403249/pexels-photo-9403249.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-199.jpeg
# curl -L "https://images.pexels.com/photos/9403233/pexels-photo-9403233.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-200.jpeg
# curl -L "https://images.pexels.com/photos/14094459/pexels-photo-14094459.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-201.jpeg
# curl -L "https://images.pexels.com/photos/12299042/pexels-photo-12299042.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-202.jpeg
# curl -L "https://images.pexels.com/photos/4078599/pexels-photo-4078599.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-203.jpeg
# curl -L "https://images.pexels.com/photos/5620129/pexels-photo-5620129.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-204.jpeg
# curl -L "https://images.pexels.com/photos/10259011/pexels-photo-10259011.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-205.jpeg
# curl -L "https://images.pexels.com/photos/10046153/pexels-photo-10046153.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-206.jpeg
# curl -L "https://images.pexels.com/photos/9283757/pexels-photo-9283757.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-207.jpeg
# curl -L "https://images.pexels.com/photos/11579270/pexels-photo-11579270.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-208.jpeg
# curl -L "https://images.pexels.com/photos/11250388/pexels-photo-11250388.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-209.jpeg
# curl -L "https://images.pexels.com/photos/9559782/pexels-photo-9559782.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-210.jpeg
# curl -L "https://images.pexels.com/photos/11247840/pexels-photo-11247840.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-211.jpeg
# curl -L "https://images.pexels.com/photos/11106635/pexels-photo-11106635.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-212.jpeg
# curl -L "https://images.pexels.com/photos/13067864/pexels-photo-13067864.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-213.jpeg
# curl -L "https://images.pexels.com/photos/14423060/pexels-photo-14423060.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-214.jpeg
# curl -L "https://images.pexels.com/photos/2438245/pexels-photo-2438245.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-215.jpeg
# curl -L "https://images.pexels.com/photos/4939717/pexels-photo-4939717.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-216.jpeg
# curl -L "https://images.pexels.com/photos/5306625/pexels-photo-5306625.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-217.jpeg
# curl -L "https://images.pexels.com/photos/4201122/pexels-photo-4201122.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-218.jpeg
# curl -L "https://images.pexels.com/photos/4148682/pexels-photo-4148682.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-219.jpeg
# curl -L "https://images.pexels.com/photos/3031258/pexels-photo-3031258.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-220.jpeg
# curl -L "https://images.pexels.com/photos/6189395/pexels-photo-6189395.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-221.jpeg
# curl -L "https://images.pexels.com/photos/5819163/pexels-photo-5819163.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-222.jpeg
# curl -L "https://images.pexels.com/photos/5821744/pexels-photo-5821744.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-223.jpeg
# curl -L "https://images.pexels.com/photos/5691353/pexels-photo-5691353.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-224.jpeg
# curl -L "https://images.pexels.com/photos/5499620/pexels-photo-5499620.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-225.jpeg
# curl -L "https://images.pexels.com/photos/5442197/pexels-photo-5442197.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-226.jpeg
# curl -L "https://images.pexels.com/photos/6437432/pexels-photo-6437432.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-227.jpeg
# curl -L "https://images.pexels.com/photos/5928130/pexels-photo-5928130.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-228.jpeg
# curl -L "https://images.pexels.com/photos/6457079/pexels-photo-6457079.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-229.jpeg
# curl -L "https://images.pexels.com/photos/7070933/pexels-photo-7070933.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-230.jpeg
# curl -L "https://images.pexels.com/photos/7465289/pexels-photo-7465289.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-231.jpeg
# curl -L "https://images.pexels.com/photos/7888180/pexels-photo-7888180.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-232.jpeg
# curl -L "https://images.pexels.com/photos/7165335/pexels-photo-7165335.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-233.jpeg
# curl -L "https://images.pexels.com/photos/10489707/pexels-photo-10489707.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-234.jpeg
# curl -L "https://images.pexels.com/photos/8975671/pexels-photo-8975671.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-235.jpeg
# curl -L "https://images.pexels.com/photos/10046151/pexels-photo-10046151.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-236.jpeg
# curl -L "https://images.pexels.com/photos/10107525/pexels-photo-10107525.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-237.jpeg
# curl -L "https://images.pexels.com/photos/10602526/pexels-photo-10602526.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-238.jpeg
# curl -L "https://images.pexels.com/photos/7730416/pexels-photo-7730416.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-239.jpeg
# curl -L "https://images.pexels.com/photos/12167728/pexels-photo-12167728.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-240.jpeg
# curl -L "https://images.pexels.com/photos/12303592/pexels-photo-12303592.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-241.jpeg
# curl -L "https://images.pexels.com/photos/13266053/pexels-photo-13266053.jpeg?auto=compress&cs=tinysrgb&w=1600"  --output pexels-photo-242.jpeg


# Upload all (no worries if a curl failed we just take what we downloaded)
# gcloud storage cp *.jpeg "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/"

# Set some meta-data
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-1008155.jpeg" --custom-metadata="location_id=1"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-1.jpeg" --custom-metadata="location_id=1"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-2.jpeg" --custom-metadata="location_id=2"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-3.jpeg" --custom-metadata="location_id=3"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-4.jpeg" --custom-metadata="location_id=4"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-5.jpeg" --custom-metadata="location_id=5"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-6.jpeg" --custom-metadata="location_id=6"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-7.jpeg" --custom-metadata="location_id=7"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-8.jpeg" --custom-metadata="location_id=8"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-9.jpeg" --custom-metadata="location_id=9"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-10.jpeg" --custom-metadata="location_id=10"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-11.jpeg" --custom-metadata="location_id=11"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-12.jpeg" --custom-metadata="location_id=12"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-13.jpeg" --custom-metadata="location_id=13"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-14.jpeg" --custom-metadata="location_id=14"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-15.jpeg" --custom-metadata="location_id=15"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-16.jpeg" --custom-metadata="location_id=16"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-17.jpeg" --custom-metadata="location_id=17"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-18.jpeg" --custom-metadata="location_id=18"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-19.jpeg" --custom-metadata="location_id=19"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-20.jpeg" --custom-metadata="location_id=20"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-21.jpeg" --custom-metadata="location_id=21"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-22.jpeg" --custom-metadata="location_id=22"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-23.jpeg" --custom-metadata="location_id=23"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-24.jpeg" --custom-metadata="location_id=24"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-25.jpeg" --custom-metadata="location_id=25"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-26.jpeg" --custom-metadata="location_id=26"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-27.jpeg" --custom-metadata="location_id=27"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-28.jpeg" --custom-metadata="location_id=28"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-29.jpeg" --custom-metadata="location_id=29"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-30.jpeg" --custom-metadata="location_id=30"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-31.jpeg" --custom-metadata="location_id=31"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-32.jpeg" --custom-metadata="location_id=32"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-33.jpeg" --custom-metadata="location_id=33"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-34.jpeg" --custom-metadata="location_id=34"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-35.jpeg" --custom-metadata="location_id=35"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-36.jpeg" --custom-metadata="location_id=36"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-37.jpeg" --custom-metadata="location_id=37"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-38.jpeg" --custom-metadata="location_id=38"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-39.jpeg" --custom-metadata="location_id=39"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-40.jpeg" --custom-metadata="location_id=40"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-41.jpeg" --custom-metadata="location_id=41"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-42.jpeg" --custom-metadata="location_id=42"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-43.jpeg" --custom-metadata="location_id=43"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-44.jpeg" --custom-metadata="location_id=44"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-45.jpeg" --custom-metadata="location_id=45"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-46.jpeg" --custom-metadata="location_id=46"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-47.jpeg" --custom-metadata="location_id=47"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-48.jpeg" --custom-metadata="location_id=48"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-49.jpeg" --custom-metadata="location_id=49"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-50.jpeg" --custom-metadata="location_id=50"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-51.jpeg" --custom-metadata="location_id=51"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-52.jpeg" --custom-metadata="location_id=52"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-53.jpeg" --custom-metadata="location_id=53"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-54.jpeg" --custom-metadata="location_id=54"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-55.jpeg" --custom-metadata="location_id=55"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-56.jpeg" --custom-metadata="location_id=56"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-57.jpeg" --custom-metadata="location_id=57"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-58.jpeg" --custom-metadata="location_id=58"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-59.jpeg" --custom-metadata="location_id=59"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-60.jpeg" --custom-metadata="location_id=60"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-61.jpeg" --custom-metadata="location_id=61"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-62.jpeg" --custom-metadata="location_id=62"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-63.jpeg" --custom-metadata="location_id=63"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-64.jpeg" --custom-metadata="location_id=64"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-65.jpeg" --custom-metadata="location_id=65"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-66.jpeg" --custom-metadata="location_id=66"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-67.jpeg" --custom-metadata="location_id=67"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-68.jpeg" --custom-metadata="location_id=68"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-69.jpeg" --custom-metadata="location_id=69"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-70.jpeg" --custom-metadata="location_id=70"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-71.jpeg" --custom-metadata="location_id=71"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-72.jpeg" --custom-metadata="location_id=72"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-73.jpeg" --custom-metadata="location_id=73"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-74.jpeg" --custom-metadata="location_id=74"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-75.jpeg" --custom-metadata="location_id=75"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-76.jpeg" --custom-metadata="location_id=76"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-77.jpeg" --custom-metadata="location_id=77"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-78.jpeg" --custom-metadata="location_id=78"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-79.jpeg" --custom-metadata="location_id=79"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-80.jpeg" --custom-metadata="location_id=80"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-81.jpeg" --custom-metadata="location_id=81"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-82.jpeg" --custom-metadata="location_id=82"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-83.jpeg" --custom-metadata="location_id=83"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-84.jpeg" --custom-metadata="location_id=84"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-85.jpeg" --custom-metadata="location_id=85"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-86.jpeg" --custom-metadata="location_id=86"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-87.jpeg" --custom-metadata="location_id=87"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-88.jpeg" --custom-metadata="location_id=88"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-89.jpeg" --custom-metadata="location_id=89"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-90.jpeg" --custom-metadata="location_id=90"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-91.jpeg" --custom-metadata="location_id=91"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-92.jpeg" --custom-metadata="location_id=92"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-93.jpeg" --custom-metadata="location_id=93"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-94.jpeg" --custom-metadata="location_id=94"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-95.jpeg" --custom-metadata="location_id=95"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-96.jpeg" --custom-metadata="location_id=96"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-97.jpeg" --custom-metadata="location_id=97"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-98.jpeg" --custom-metadata="location_id=98"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-99.jpeg" --custom-metadata="location_id=99"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-100.jpeg" --custom-metadata="location_id=100"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-101.jpeg" --custom-metadata="location_id=101"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-102.jpeg" --custom-metadata="location_id=102"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-103.jpeg" --custom-metadata="location_id=103"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-104.jpeg" --custom-metadata="location_id=104"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-105.jpeg" --custom-metadata="location_id=105"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-106.jpeg" --custom-metadata="location_id=106"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-107.jpeg" --custom-metadata="location_id=107"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-108.jpeg" --custom-metadata="location_id=108"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-109.jpeg" --custom-metadata="location_id=109"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-110.jpeg" --custom-metadata="location_id=110"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-111.jpeg" --custom-metadata="location_id=111"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-112.jpeg" --custom-metadata="location_id=112"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-113.jpeg" --custom-metadata="location_id=113"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-114.jpeg" --custom-metadata="location_id=114"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-115.jpeg" --custom-metadata="location_id=115"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-116.jpeg" --custom-metadata="location_id=116"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-117.jpeg" --custom-metadata="location_id=117"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-118.jpeg" --custom-metadata="location_id=118"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-119.jpeg" --custom-metadata="location_id=119"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-120.jpeg" --custom-metadata="location_id=120"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-121.jpeg" --custom-metadata="location_id=121"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-122.jpeg" --custom-metadata="location_id=122"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-123.jpeg" --custom-metadata="location_id=123"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-124.jpeg" --custom-metadata="location_id=124"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-125.jpeg" --custom-metadata="location_id=125"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-126.jpeg" --custom-metadata="location_id=126"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-127.jpeg" --custom-metadata="location_id=127"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-128.jpeg" --custom-metadata="location_id=128"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-129.jpeg" --custom-metadata="location_id=129"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-130.jpeg" --custom-metadata="location_id=130"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-131.jpeg" --custom-metadata="location_id=131"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-132.jpeg" --custom-metadata="location_id=132"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-133.jpeg" --custom-metadata="location_id=133"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-134.jpeg" --custom-metadata="location_id=134"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-135.jpeg" --custom-metadata="location_id=135"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-136.jpeg" --custom-metadata="location_id=136"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-137.jpeg" --custom-metadata="location_id=137"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-138.jpeg" --custom-metadata="location_id=138"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-139.jpeg" --custom-metadata="location_id=139"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-140.jpeg" --custom-metadata="location_id=140"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-141.jpeg" --custom-metadata="location_id=141"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-142.jpeg" --custom-metadata="location_id=142"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-143.jpeg" --custom-metadata="location_id=143"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-144.jpeg" --custom-metadata="location_id=144"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-145.jpeg" --custom-metadata="location_id=145"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-146.jpeg" --custom-metadata="location_id=146"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-147.jpeg" --custom-metadata="location_id=147"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-148.jpeg" --custom-metadata="location_id=148"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-149.jpeg" --custom-metadata="location_id=149"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-150.jpeg" --custom-metadata="location_id=150"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-151.jpeg" --custom-metadata="location_id=151"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-152.jpeg" --custom-metadata="location_id=152"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-153.jpeg" --custom-metadata="location_id=153"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-154.jpeg" --custom-metadata="location_id=154"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-155.jpeg" --custom-metadata="location_id=155"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-156.jpeg" --custom-metadata="location_id=156"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-157.jpeg" --custom-metadata="location_id=157"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-158.jpeg" --custom-metadata="location_id=158"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-159.jpeg" --custom-metadata="location_id=159"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-160.jpeg" --custom-metadata="location_id=160"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-161.jpeg" --custom-metadata="location_id=161"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-162.jpeg" --custom-metadata="location_id=162"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-163.jpeg" --custom-metadata="location_id=163"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-164.jpeg" --custom-metadata="location_id=164"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-165.jpeg" --custom-metadata="location_id=165"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-166.jpeg" --custom-metadata="location_id=166"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-167.jpeg" --custom-metadata="location_id=167"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-168.jpeg" --custom-metadata="location_id=168"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-169.jpeg" --custom-metadata="location_id=169"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-170.jpeg" --custom-metadata="location_id=170"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-171.jpeg" --custom-metadata="location_id=171"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-172.jpeg" --custom-metadata="location_id=172"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-173.jpeg" --custom-metadata="location_id=173"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-174.jpeg" --custom-metadata="location_id=174"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-175.jpeg" --custom-metadata="location_id=175"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-176.jpeg" --custom-metadata="location_id=176"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-177.jpeg" --custom-metadata="location_id=177"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-178.jpeg" --custom-metadata="location_id=178"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-179.jpeg" --custom-metadata="location_id=179"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-180.jpeg" --custom-metadata="location_id=180"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-181.jpeg" --custom-metadata="location_id=181"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-182.jpeg" --custom-metadata="location_id=182"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-183.jpeg" --custom-metadata="location_id=183"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-184.jpeg" --custom-metadata="location_id=184"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-185.jpeg" --custom-metadata="location_id=185"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-186.jpeg" --custom-metadata="location_id=186"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-187.jpeg" --custom-metadata="location_id=187"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-188.jpeg" --custom-metadata="location_id=188"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-189.jpeg" --custom-metadata="location_id=189"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-190.jpeg" --custom-metadata="location_id=190"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-191.jpeg" --custom-metadata="location_id=191"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-192.jpeg" --custom-metadata="location_id=192"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-193.jpeg" --custom-metadata="location_id=193"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-194.jpeg" --custom-metadata="location_id=194"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-195.jpeg" --custom-metadata="location_id=195"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-196.jpeg" --custom-metadata="location_id=196"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-197.jpeg" --custom-metadata="location_id=197"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-198.jpeg" --custom-metadata="location_id=198"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-199.jpeg" --custom-metadata="location_id=199"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-200.jpeg" --custom-metadata="location_id=200"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-201.jpeg" --custom-metadata="location_id=201"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-202.jpeg" --custom-metadata="location_id=202"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-203.jpeg" --custom-metadata="location_id=203"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-204.jpeg" --custom-metadata="location_id=204"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-205.jpeg" --custom-metadata="location_id=205"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-206.jpeg" --custom-metadata="location_id=206"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-207.jpeg" --custom-metadata="location_id=207"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-208.jpeg" --custom-metadata="location_id=208"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-209.jpeg" --custom-metadata="location_id=209"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-210.jpeg" --custom-metadata="location_id=210"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-211.jpeg" --custom-metadata="location_id=211"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-212.jpeg" --custom-metadata="location_id=212"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-213.jpeg" --custom-metadata="location_id=213"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-214.jpeg" --custom-metadata="location_id=214"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-215.jpeg" --custom-metadata="location_id=215"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-216.jpeg" --custom-metadata="location_id=216"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-217.jpeg" --custom-metadata="location_id=217"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-218.jpeg" --custom-metadata="location_id=218"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-219.jpeg" --custom-metadata="location_id=219"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-220.jpeg" --custom-metadata="location_id=220"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-221.jpeg" --custom-metadata="location_id=221"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-222.jpeg" --custom-metadata="location_id=222"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-223.jpeg" --custom-metadata="location_id=223"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-224.jpeg" --custom-metadata="location_id=224"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-225.jpeg" --custom-metadata="location_id=225"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-226.jpeg" --custom-metadata="location_id=226"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-227.jpeg" --custom-metadata="location_id=227"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-228.jpeg" --custom-metadata="location_id=228"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-229.jpeg" --custom-metadata="location_id=229"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-230.jpeg" --custom-metadata="location_id=230"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-231.jpeg" --custom-metadata="location_id=231"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-232.jpeg" --custom-metadata="location_id=232"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-233.jpeg" --custom-metadata="location_id=233"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-234.jpeg" --custom-metadata="location_id=234"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-235.jpeg" --custom-metadata="location_id=235"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-236.jpeg" --custom-metadata="location_id=236"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-237.jpeg" --custom-metadata="location_id=237"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-238.jpeg" --custom-metadata="location_id=238"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-239.jpeg" --custom-metadata="location_id=239"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-240.jpeg" --custom-metadata="location_id=240"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-241.jpeg" --custom-metadata="location_id=241"
# gcloud storage objects update "gs://${RIDESHARE_RAW_BUCKET}/rideshare_images/pexels-photo-242.jpeg" --custom-metadata="location_id=242"

# To do: apply 
cd ..
rm -R images