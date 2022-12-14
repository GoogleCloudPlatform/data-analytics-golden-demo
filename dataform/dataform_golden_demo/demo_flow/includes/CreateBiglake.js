/*##################################################################################
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
###################################################################################*/

/*
The function CreateBiglake() takes as input two arguments: table name and gcs file path,
and calls a BQ stored procedure to create a biglake table
* You can learn more about functions on https://cloud.google.com/dataform/docs/reuse-code-includes
*/
 
function CreateBiglake(name, uris) {
 return `call dataform_demo.create_biglake_table(${name},"${uris}")`;
}
     
module.exports = {
    CreateBiglake
};
    