# autogen-indices
Lightweight demo of using sdmTMB to automate index standardization with Github actions

Model fitting: [![R-run-models1](https://github.com/DFO-NOAA-Pacific/autogen-indices/actions/workflows/R-run-models.yml/badge.svg)](https://github.com/DFO-NOAA-Pacific/autogen-indices/actions/workflows/R-run-models.yml)

# Notes on workflow setup:
Github actions currently timeout after 6 hours, so by dividing the total model runs across runners, the run time can be greatly reduced and all jobs will finish. The setup used is based on https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow. For this application, there's a little over 40 models that need running, so there are 24 runners assigned to these: https://github.com/DFO-NOAA-Pacific/autogen-indices/blob/e90905dab568a829406d877297bbc6ca2383ff09/.github/workflows/R-run-models.yml#L15. More runners can be added -- if so, they also need to be increased here: https://github.com/DFO-NOAA-Pacific/autogen-indices/blob/e90905dab568a829406d877297bbc6ca2383ff09/code/01_calculate_indices.R#L12.

The second issue with the actions is the processing of results. Because of previous conflicts with the workflows yml, the approach here is to save results to artifacts: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/storing-and-sharing-data-from-a-workflow. The second workflow, https://github.com/DFO-NOAA-Pacific/autogen-indices/blob/main/.github/workflows/R-commit-results.yml, processes these artifacts, extracts .csv files, and adds them to a new branch. 
