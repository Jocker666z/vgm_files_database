This little project was born with the aim of giving personalised information to glouglou music player (https://github.com/Jocker666z/glouglou), but it can also be used in any way you like. In fact, many formats give little or no information about the files being played.

## Usage
```
Usage: vgmfdb [options]
  -h|--help                       Display this help.

 Files search:
                                      Without option inplace recursively add files in db.
  -i|--input <directory/file>         Target search directory or file.
  -ft|--filter_type "ext0|ext1"       Selects only the given file extension(s).

   -i is cumulative: -i <dir0> -i <dir1> -i <file>...

 Database query:
  -gt|--get_current_tags              Display tags in db of current files.

 Database manipulation:
  -idrm|--id_forced_remove            Force remove current files from db.
  --no_purge_db                       Desactivate database cleanup.
  -tfal|--tag_forced_album "text"     Force album name.
  -tfar|--tag_forced_artist "text"    Force artist name.
  -tfs|--tag_forced_system "text"     Force system name.
  -tft|--tag_forced_title "text"      Force title name.
  -tftf|--tag_forced_ftitle           Force title name as filename.
  -tfte|--tag_forced_etitle "integer" Force remove N character at the end of title.
  -tfts|--tag_forced_stitle "integer" Force remove N character at beginning of title.
  -tftp|--tag_forced_ptitle "text"    Force remove a pattern in title.

   Be careful with forced, no selection = recursive action.
```

## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/vgm_files_database/main/vgmfdb.sh > /home/$USER/.local/bin/vgmfdb && chmod +rx /home/$USER/.local/bin/vgmfdb`

## Tags read
By default the tags are taken with the filename and the directory that contains them. For more precision you will have to install the dependencies below.

* `info68`: https://sourceforge.net/projects/sc68/
* `openmpt123`: present in many official repositories
* `vgm_tag`: https://github.com/vgmrips/vgmtools
* `vgmstream-cli`: https://vgmstream.org/
* `xmp`: present in many official repositories
* `xxd`: present in many official repositories

## vgmfdb.nfo usage
It is possible to tag all files in a directory with a `vgmfdb.nfo` file (must be in the same directory as the files to be tagged). This file can contain the artist, album (games) and system. See example below.
```
artist=David Whittaker
album=Xenon 2 - Megablast
system=Amiga
```

## Supported Files
* AdLib
	* `adl|amd|bam|cff|cmf|d00|dfm|ddt|dmo|dtm|got|hsc|hsq|imf|laa|ksm|m|mdi|mtk|rad|rol|sdb|sqx|tm|wlf|xms|xsm`
* Atari 8-bits
	* `sap`
* Atari ST & Amiga
	* `sc68|snd|sndh`
* Commodore
	* `sid|prg`
* Sony PS1, PS2; Sega Saturn, Dreamcast; Nintendo 64, DS, GBA:
	* `2sf|gsf|dsf|psf|psf2|mini2sf|minigsf|minipsf|minipsf2|minissf|miniusf|minincsf|ncsf|ssf|usf`
* Nintendo SNES/Super Famicom:
	* `spc`
* Various machine:
	* `ay|ams|dmf|dtt|hmi|hmp|hvl|mdx|mid|rmt|s98|sap|v2m|vt2|vtx|xmi|xrns|ym`
* Various machine (vgmplay supported files):
	* `vgm|vgz`
* Various machine (vgmstream supported files):
	* `22k|8svx|acb|acm|ads|adp|adpcm|ad|adx|aix|akb|asf|apc|at3|at9|awb|bcstm|bcwav|bfstm|bfwav|bik|brstm|bwav|cfn|ckd|csb|cmp|csmp|cps|dsm|dsp|dvi|fsb|gcm|genh|h4m|hca|hps|ifs|imc|int|isd|ivs|kma|ks|kvs|lac3|lbin|lmp3|logg|lopus|lstm|lwav|mab|mca|mic|msf|mus|musx|nlsd|nop|npsf|oma|ras|rsd|rsnd|rws|sad|sap|scd|sfx|sgd|snd|ss2|str|strm|stx|svag|p04|p08|p16|pcm|psb|thp|trk|trs|txtp|ulw|vag|vas|vig|vgmstream|voi|wem|xa|xai|xma|xnb|xwv`
* Tracker (openmpt supported files):
	* `it|mod|mo3|mptm|s3m|stm|stp|plm|umx|xm`
* Tracker (uade supported files):
	* `aam|abk|ahx|amc|aon|ast|bss|bp|bp3|cm|cus|dm|dm2|dmu|dss|dw|ea|ex|gmc|hot|fc13|fc14|med|mug|np3|okt|pru2|rk|s7g|sfx|smus|soc|p4x|tiny|tw`
* Tracker (xmp supported files):
	* `669|amf|dbm|digi|dsm|dsym|far|gz|mdl|musx|psm`
* ZX Spectrum:
	* `asc|psc|pt1|pt2|pt3|sqt|stc|stp|tap|zxs`

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
