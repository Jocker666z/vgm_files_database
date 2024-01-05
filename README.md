This little project was born with the aim of giving personalised information to glouglou music player (https://github.com/Jocker666z/glouglou). In fact, many formats give little or no information about the files being played.

## Usage
```
                                   Without option inplace recursively add files in db.
  -h|--help                        Display this help.
  -i|--input <directory>           Target search directory.
  --tag_forced_album "text"        Force album name.
  --tag_forced_artist "text"       Force artist name.

   -i is cumulative: -i <dir0> -i <dir1> ...
   Be careful with --tag_forced, no selection = recursive action.
```

## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/vgm_files_database/main/vgmfdb.sh > /home/$USER/.local/bin/vgmfdb && chmod +rx /home/$USER/.local/bin/vgmfdb`

## Supported Files

* `2sf|gsf|dsf|psf|psf2|mini2sf|minigsf|minipsf|minipsf2|minissf|miniusf|minincsf|ncsf|ssf|usf`
* `vgm|vgz`

## db SPEC
* Database location = `/home/$USER/.config/vgmfdb/vgm.db`
* Table = `vgm`
* Table column :
	* id = TEXT; sha256sum of file path+size+timestamp
	* path = TEXT; absolute path of file
	* title = TEXT; tag title
	* artist = TEXT; tag artist
	* album = TEXT; tag album
	* type = TEXT; file extension, in uppercase
	* size = INTEGER; size of file in bytes (wc -c)
	* frequency = INTEGER; frequency of file in Hz
	* duration = INTEGER; total duration of file in second
	* system = TEXT; original system or file info
	* timestamp = TEXT; timestamp of file since Epoch (date -r FILE "+%s")
	* add_date = TEXT; date of addition in database since Epoch $(date "+%s")
	* tag_forced = INTEGER; internal use, for forced/update manipulation
