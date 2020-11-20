- Cloned iostat-tool, made modifications for Mac and iostat files I have

# Running
## Setup IOStat
- `mkdir -p virtualenvs`
- `virtualenv -p python3 virtualenvs/venv`
- `source virtualenvs/venv/bin/activate`
- `(cd iostat-tool && python setup.py develop)`

## Get the perf data
- `mkdir -p data && cp perfdata.zip data`
- `(cd data && unzip perfdata.zip)`
- `script/dumpcsv.sh data output`
- `script/aggregate.sh output reponame`