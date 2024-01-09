#!/usr/bin/env bash
# shellcheck disable=SC2207
# vgmfdb
# Bash script for populate sqlite database with vgm
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/vgm_files_database/
# Licence : Unlicense

bin() {
local bin_name
local system_bin_location

# info68
bin_name="info68"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	info68_bin="$system_bin_location"
fi

bin_name="openmpt123"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	openmpt123_bin="$system_bin_location"
fi

# vgm_tag
bin_name="vgm_tag"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	vgm_tag_bin="$system_bin_location"
fi
 
# vgmstream-cli
bin_name="vgmstream-cli"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	vgmstream_cli_bin="$system_bin_location"
fi

# xmp
bin_name="xmp"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	xmp_bin="$system_bin_location"
fi

# xxd
bin_name="xxd"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	xxd_bin="$system_bin_location"
fi
}
config() {
if [[ ! -d "$vgmfdb_config_dir" ]] && [[ -w "/home/$USER/.config/" ]]; then
	mkdir "$vgmfdb_config_dir"
elif [[ ! -d "$vgmfdb_config_dir" ]] && [[ ! -w "/home/$USER/.config/" ]]; then
	echo_error "vgmfdb was breaked."
	echo_error "Impossible to create ${vgmfdb_config_dir}, not writable."
	exit
fi
}
echo_error() {
local error_label
error_label="$1"

echo "${error_label}" >&2
}
kill () {
local time_formated

# Print stats
if [[ "${SECONDS}" -gt "120" ]]; then
	time_formated="$((SECONDS/3600))h$((SECONDS%3600/60))m$((SECONDS%60))s"
	echo "Total duration of operation is ${time_formated}".
else
	echo "Total duration of operation is ${SECONDS}s".
fi

rm "$temp_cache_tags" &>/dev/null
stty sane
exit
}
usage() {
cat <<- EOF
vgmfdb - <https://github.com/Jocker666z/vgm_files_database>
Bash script for populate sqlite database with various type of vgm files.

Usage: vgmfdb [options]
  -h|--help                       Display this help.

 Files search:
                                  Without option inplace recursively add files in db.
  -i|--input <directory/file>     Target search directory or file.
  --input_filter_type "ext0|ext1" Selects only the given file extension(s).

   -i is cumulative: -i <dir0> -i <dir1> -i <file>...

 Database query:
  --get_current_tags              Display tags in db of current files.

 Database manipulation:
  --id_forced_remove              Force remove current files from db.
  --tag_forced_album "text"       Force album name.
  --tag_forced_artist "text"      Force artist name.
  --tag_forced_system "text"      Force system name.
  --tag_forced_etitle "integer"   Force remove N character at the end of title.
  --tag_forced_stitle "integer"   Force remove N character at beginning of title.

   Be careful with forced, no selection = recursive action.
EOF
}

# Search files
search_vgm() {
local input_realpath
local oldIFS

oldIFS="$IFS"

# If type filter
if [[ -n "$input_filter_type" ]]; then
	ext_all="${input_filter_type,,}"
fi

# If no input dir
if ! (( "${#input_dir[@]}" )); then
	input_dir=( "$PWD" )
fi

# Change IFS
IFS=$'\n'

for input in "${input_dir[@]}"; do
	input_realpath=$(realpath "$input")
	lst_vgm+=( $(find "${input_realpath}" -type f -regextype posix-egrep -iregex '.*\.('$ext_all')$') )
done

# Reset IFS
IFS="$oldIFS"

# Remove duplicate
mapfile -t lst_vgm <  <(printf '%s\n' "${lst_vgm[@]}" | sort -u)
}

# db change
# path
# title
# album
# artist
# type (file type)
# size (in byte = wc -c)
# frequency
# duration (total in s)
# system (original system or file info)
# timestamp
# adddate
db_create() {
if [[ ! -f "$vgmfdb_database" ]]; then
sqlite3 "$vgmfdb_database" <<EOF
CREATE TABLE vgm (id TEXT PRIMARY KEY);
ALTER TABLE vgm ADD COLUMN path TEXT;
ALTER TABLE vgm ADD COLUMN title TEXT;
ALTER TABLE vgm ADD COLUMN artist TEXT;
ALTER TABLE vgm ADD COLUMN album TEXT;
ALTER TABLE vgm ADD COLUMN type TEXT;
ALTER TABLE vgm ADD COLUMN size INTEGER;
ALTER TABLE vgm ADD COLUMN frequency INTEGER;
ALTER TABLE vgm ADD COLUMN duration INTEGER;
ALTER TABLE vgm ADD COLUMN system TEXT;
ALTER TABLE vgm ADD COLUMN timestamp TEXT;
ALTER TABLE vgm ADD COLUMN add_date TEXT;
ALTER TABLE vgm ADD COLUMN tag_forced INTEGER;
EOF
fi
}
db_add() {
local damn

# Quote sub
damn="''"

# Replace / by - ; cause display error
tag_title="${tag_title//\//-}"
tag_artist="${tag_artist//\//-}"
tag_album="${tag_album//\//-}"
tag_system="${tag_system//\//-}"

sqlite3 "$vgmfdb_database" <<EOF
INSERT OR IGNORE INTO vgm (\
	id, \
	path, \
	title, \
	artist, \
	album, \
	type, \
	size, \
	frequency, \
	duration, \
	system, \
	timestamp, \
	add_date, \
	tag_forced \
	) \
	VALUES (\
		'$tag_id', \
		'${tag_path//\'/$damn}', \
		'${tag_title//\'/$damn}', \
		'${tag_artist//\'/$damn}', \
		'${tag_album//\'/$damn}', \
		'$tag_type', \
		'$tag_size', \
		'$tag_frequency', \
		'$tag_duration', \
		'${tag_system//\'/$damn}', \
		'$tag_timestamp', \
		'$tag_add_date', \
		'$tag_forced' \
		);
EOF
}
db_remove() {
sqlite3 "$vgmfdb_database" "DELETE FROM vgm WHERE id = '${tag_id}'"
}
db_purge() {
local damn
local input_realpath
local vgm_removed

# Quote sub
damn="''"

if [[ -z "$id_forced_remove" ]]; then

	vgm_removed="0"

	# Limit clean at the directory selected 
	for input in "${input_dir[@]}"; do
		input_realpath=$(realpath "$input")
		mapfile -t clear_id_lst < <(sqlite3 "$vgmfdb_database" \
									"SELECT id FROM vgm WHERE path \
									LIKE '${input_realpath//\'/$damn}%'")
	done
	# List orphan/removed
	mapfile -t clear_id_lst < <(printf '%s\n' "${clear_id_lst[@]}" "${add_id_lst[@]}" \
								| sort | uniq -u)

	for value in "${clear_id_lst[@]}"; do

		sqlite3 "$vgmfdb_database" "DELETE FROM vgm WHERE id = '${value}'"
		vgm_removed=$(( vgm_removed + 1 ))

		# Print
		tput bold sitm
		echo -e " Purge; clean files in db \u2933 $vgm_removed"
		tput sgr0
		# Cursor up 1 lines
		if [[ "$vgm_removed" != "${#clear_id_lst[@]}" ]]; then
			printf "\033[1A"
		fi

	done

fi

sqlite3 "$vgmfdb_database" 'VACUUM;'
}
db_force_update_album() {
if [[ -n "$tag_forced_album" ]]; then
	local id
	local album
	local damn
	id="$1"
	# Quote sub
	damn="''"

	album=$(sqlite3 "$vgmfdb_database" "SELECT album FROM vgm WHERE id = '${id}'")

	if [[ "$tag_album" != "$album" ]]; then
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET album = '${tag_album//\'/$damn}' WHERE id = '$id'"
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
		vgm_updated_true="1"
	else
		vgm_updated_true="0"
	fi
fi
}
db_force_update_artist() {
if [[ -n "$tag_forced_artist" ]]; then
	local id
	local artist
	local damn
	id="$1"
	# Quote sub
	damn="''"

	artist=$(sqlite3 "$vgmfdb_database" "SELECT artist FROM vgm WHERE id = '${id}'")

	if [[ "$tag_artist" != "$artist" ]]; then
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET artist = '${tag_artist//\'/$damn}' WHERE id = '$id'"
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
		vgm_updated_true="1"
	else
		vgm_updated_true="0"
	fi
fi
}
db_force_update_system() {
if [[ -n "$tag_forced_system" ]]; then
	local id
	local system
	local damn
	id="$1"
	# Quote sub
	damn="''"

	system=$(sqlite3 "$vgmfdb_database" "SELECT system FROM vgm WHERE id = '${id}'")

	if [[ "$tag_system" != "$system" ]]; then
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET system = '${tag_system//\'/$damn}' WHERE id = '$id'"
		sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
		vgm_updated_true="1"
	else
		vgm_updated_true="0"
	fi
fi
}
db_force_update_stitle() {
if [[ -n "$tag_forced_stitle" ]]; then
	local id
	local title
	local damn
	id="$1"
	# Quote sub
	damn="''"

	title=$(sqlite3 "$vgmfdb_database" "SELECT title \
			FROM vgm WHERE id = '${id}'")
	title="${title:${tag_forced_stitle}}"

	sqlite3 "$vgmfdb_database" "UPDATE vgm SET title = '${title//\'/$damn}' WHERE id = '$id'"
	sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
	vgm_updated_true="1"
fi
}
db_force_update_etitle() {
if [[ -n "$tag_forced_etitle" ]]; then
	local id
	local title
	local damn
	id="$1"
	# Quote sub
	damn="''"

	title=$(sqlite3 "$vgmfdb_database" "SELECT title \
			FROM vgm WHERE id = '${id}'")
	title="${title:0:-${tag_forced_etitle}}"

	sqlite3 "$vgmfdb_database" "UPDATE vgm SET title = '${title//\'/$damn}' WHERE id = '$id'"
	sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
	vgm_updated_true="1"
fi
}

# db query
db_id() {
mapfile -t dbquery_id_lst < <(sqlite3 "$vgmfdb_database" "SELECT id FROM vgm")
}
db_get_current_tags() {
local oldIFS

if [[ -n "$get_current_tags" ]]; then
	# Change IFS
	IFS=$'\n'
	for value in "${add_id_lst[@]}"; do
		lst_db_get_current_tags+=( $(sqlite3 "$vgmfdb_database" "SELECT path, title, artist, album, system, type \
									FROM vgm WHERE id = '${value}'" \
									| rev | cut -d'/' -f-1 | rev) )
	done
	# Reset IFS
	IFS="$oldIFS"

	# Print tag
	echo "--------------------------"
	printf '%s\n' "${lst_db_get_current_tags[@]}" \
		| sort -V \
		| column -T 1,3 -s $'|' -t -o ' | ' -N "Current files tags,title,artist,album,system,type"
	echo "--------------------------"
fi
}

# Tag specific
tag_reset() {
# Reset
unset tag_id
unset tag_path
unset tag_size
unset tag_timestamp
unset tag_title
unset tag_artist
unset tag_album
unset tag_type
unset tag_frequency
unset tag_duration
unset tag_system
unset tag_add_date
}
tag_default() {
local file
file="$1"

if [[ -z "$tag_title" ]]; then
	tag_title=$(basename "${file%.*}")
fi
if [[ -z "$tag_album" ]]; then
	tag_album=$(dirname "$file" | rev | cut -d'/' -f-1 | rev)
	if [[ "$tag_album" = "." ]]; then
		tag_album=$(pwd -P | rev | cut -d'/' -f-1 | rev)
	fi
fi
if [[ -z "$tag_artist" ]]; then
	tag_artist="$tag_album"
fi

if [[ -z "$tag_system" ]]; then

	# tag_sytem by files ext.
	shopt -s nocasematch

	# Adlib
	if [[ "${file##*.}" = "adl" ]]; then
		tag_system="Westwood ADL"
	elif [[ "${file##*.}" = "amd" ]]; then
		tag_system="AMusic module"
	elif [[ "${file##*.}" = "bam" ]]; then
		tag_system="Bob's Adlib Music"
	elif [[ "${file##*.}" = "cff" ]]; then
		tag_system="Boom Tracker v4.0"
	elif [[ "${file##*.}" = "cmf" ]]; then
		tag_system="Creative Music Format"
	elif [[ "${file##*.}" = "d00" ]]; then
		tag_system="EdLib packed module"
	elif [[ "${file##*.}" = "dfm" ]]; then
		tag_system="Digital FM"
	elif [[ "${file##*.}" = "ddt" ]]; then
		tag_system="Jill of the Jungle Music File"
	elif [[ "${file##*.}" = "dmo" ]]; then
		tag_system="Twin TrackPlayer"
	elif [[ "${file##*.}" = "dtm" ]]; then
		tag_system="DeFy Tracker"
	elif [[ "${file##*.}" = "got" ]]; then
		tag_system="God of Thunder Music"
	elif [[ "${file##*.}" = "hsc" ]]; then
		tag_system="HSC AdLib Composer"
	elif [[ "${file##*.}" = "hsq" ]]; then
		tag_system="Herbulot AdLib"
	elif [[ "${file##*.}" = "imf" ]] || [[ "${file##*.}" = "wlf" ]]; then
		tag_system="Apogee IMF"
	elif [[ "${file##*.}" = "laa" ]]; then
		tag_system="LucasArts AdLib Module"
	elif [[ "${file##*.}" = "ksm" ]]; then
		tag_system="Ken's AdLib"
	elif [[ "${file##*.}" = "m" ]]; then
		tag_system="Ultima 6"
	elif [[ "${file##*.}" = "mdi" ]]; then
		tag_system="AdLib MIDIPlay Format"
	elif [[ "${file##*.}" = "mtk" ]]; then
		tag_system="MPU-401 Tracker"
	elif [[ "${file##*.}" = "rad" ]]; then
		tag_system="Reality AdLib Tracker"
	elif [[ "${file##*.}" = "rol" ]]; then
		tag_system="AdLib/Roland Song"
	elif [[ "${file##*.}" = "sdb" ]] || [[ "${file##*.}" = "sqx" ]]; then
		tag_system="Herad System"
	elif [[ "${file##*.}" = "xms" ]]; then
		tag_system="AMUSIC Tracker XMS"
	elif [[ "${file##*.}" = "xsm" ]]; then
		tag_system="eXtra Simple Music"

	elif [[ "${file##*.}" = "ay" ]]; then
		tag_system="AY-3-8910"

	# MIDI
	elif [[ "${file##*.}" = "mid" ]]; then
		tag_system="MIDI"

	# s98
	elif [[ "${file##*.}" = "s98" ]]; then
		tag_system="PC-Engine / TurboGrafx-16"

	# sc68
	elif [[ "${file##*.}" = "sc68" ]]; then
		tag_system="SC 68000"

	# SAP
	elif [[ "${file##*.}" = "sap" ]]; then
		tag_system="Atari 8-bit"

	# SID
	elif [[ "${file##*.}" = "sid" ]] || [[ "${file##*.}" = "prg" ]]; then
		tag_system="Comomdore 64/128"

	# SNES
	elif [[ "${file##*.}" = "spc" ]]; then
		tag_system="Super Nintendo / Super Famicom"

	# Tracker (uade)
	elif [[ "${file##*.}" = "ahx" ]]; then
		tag_system="Abyss Highest eXperience"
	elif [[ "${file##*.}" = "bp" ]]; then
		tag_system="SoundMon 2.0"
	elif [[ "${file##*.}" = "cm" ]] || [[ "${file##*.}" = "rk" ]]; then
		tag_system="CustomMade"
	elif [[ "${file##*.}" = "cus" ]]; then
		tag_system="DeliTracker Custom"
	elif [[ "${file##*.}" = "dw" ]]; then
		tag_system="David Whittaker"
	elif [[ "${file##*.}" = "fc13" ]] || [[ "${file##*.}" = "fc14" ]]; then
		tag_system="Future Composer"
	elif [[ "${file##*.}" = "gmc" ]]; then
		tag_system="Game Music Creator"
	elif [[ "${file##*.}" = "np3" ]]; then
		tag_system="Noise Packer 3.0"
	elif [[ "${file##*.}" = "okt" ]]; then
		tag_system="Oktalyzer"
	elif [[ "${file##*.}" = "pru2" ]]; then
		tag_system="Prorunner 2.0"
	elif [[ "${file##*.}" = "s7g" ]]; then
		tag_system="Jochen Hippel 7V"
	elif [[ "${file##*.}" = "sfx" ]]; then
		tag_system="SoundFX"
	elif [[ "${file##*.}" = "soc" ]]; then
		tag_system="Hippel-COSO"
	elif [[ "${file##*.}" = "tiny" ]]; then
		tag_system="Sonix Music Driver"
	elif [[ "${file##*.}" = "tw" ]]; then
		tag_system="Sound Images"

	# Tracker (zxtune)
	elif [[ "${file##*.}" = "rmt" ]]; then
		tag_system="Raster Music Tracker"
	elif [[ "${file##*.}" = "v2m" ]]; then
		tag_system="Farbrausch V2M"
	elif [[ "${file##*.}" = "vt2" ]]; then
		tag_system="Vortex Tracker 2"
	elif [[ "${file##*.}" = "vtx" ]]; then
		tag_system="Vortex Tracker"
	elif [[ "${file##*.}" = "xrns" ]]; then
		tag_system="Renoise"

	# X68000
	elif [[ "${file##*.}" = "mdx" ]]; then
		tag_system="Sharp X68000"

	# xfs (zxtune)
	elif [[ "${file##*.}" = "psf" || "${file##*.}" = "minipsf" ]]; then
		tag_system="Sony PS1"
	elif [[ "${file##*.}" = "psf2" || "${file##*.}" = "minipsf2" ]]; then
		tag_system="Sony PS2"
	elif [[ "${file##*.}" = "2sf" || "${file##*.}" = "mini2sf" || "${file##*.}" = "minincsf" || "${file##*.}" = "ncsf" ]]; then
		tag_system="Nintendo DS"
	elif [[ "${file##*.}" = "ssf" || "${file##*.}" = "minissf" ]]; then
		tag_system="Sega Saturn"
	elif [[ "${file##*.}" = "gsf" || "${file##*.}" = "minigsf" ]]; then
		tag_system="Nintendo GBA"
	elif [[ "${file##*.}" = "usf" || "${file##*.}" = "miniusf" ]]; then
		tag_system="Nintendo 64"
	elif [[ "${file##*.}" = "dsf" ]]; then
		tag_system="Sega Dreamcast"

	elif [[ "${file##*.}" = "ym" ]]; then
		tag_system="Yamaha Music"

	# ZX Spectrum (zxtune)
	elif [[ "${file##*.}" = "asc" ]]; then
		tag_system="ASC Sound Master"
	elif [[ "${file##*.}" = "psc" ]]; then
		tag_system="Pro Sound Creator"
	elif [[ "${file##*.}" = "pt1" ]] || [[ "${file##*.}" = "pt2" ]] || [[ "${file##*.}" = "pt3" ]]; then
		tag_system="Pro Tracker"
	elif [[ "${file##*.}" = "sqt" ]]; then
		tag_system="Quartet PSG Module"
	elif [[ "${file##*.}" = "stc" ]]; then
		tag_system="STC Sound Trackere"
	elif [[ "${file##*.}" = "stp" ]]; then
		tag_system="Soundtracker Pro II Module"
	elif [[ "${file##*.}" = "tap" ]]; then
		tag_system="ZX Spectrum Tape Image"
	fi

	shopt -u nocasematch

fi
}
tag_force() {
if [[ -n "$tag_forced_album" ]]; then
	tag_album="$tag_forced_album"
fi
if [[ -n "$tag_forced_artist" ]]; then
	tag_artist="$tag_forced_artist"
fi
if [[ -n "$tag_forced_system" ]]; then
	tag_system="$tag_forced_system"
fi
if [[ -n "$tag_forced_stitle" ]]; then
	tag_title="${tag_title:${tag_forced_stitle}}"
fi
}
tag_openmpt() {
local ext
local openmpt123_test_result
local xmp_test_result
local duration_record
local minute
local second
ext="$1"

if echo "|${ext_tracker_openmpt}|" | grep -i "|${ext}|" &>/dev/null \
&& [[ -n "$openmpt123_bin" ]]; then

	# Test file
	openmpt123_test_result=$("$openmpt123_bin" --info "$file" \
							| grep "error loading file")

	if [[ "${#openmpt123_test_result}" = "0" ]]; then
		# Get file tags
		"$openmpt123_bin" --info "$file" \
			> "$temp_cache_tags"

		tag_title=$(< "$temp_cache_tags" grep "Title." \
					| awk -F'.: ' '{print $NF}' | awk '{$1=$1};1')
		tag_artist=$(< "$temp_cache_tags" grep "Artist." \
					| awk -F'.: ' '{print $NF}' | awk '{$1=$1};1')
		tag_system=$(< "$temp_cache_tags" grep "Tracker....:" \
					| awk -F'.: ' '{print $NF}' | awk '{$1=$1};1')
		if [[ "${tag_system}" = "Unknown" ]] \
		|| [[ "${tag_system}" = "..converted.." ]]; then
			tag_system=$(< "$temp_cache_tags" grep "Type.......:" \
						| awk -F'[()]' '{print $2}')
		fi

		# Duration
		duration_record=$(< "$temp_cache_tags" grep "Duration." \
							| awk '{print $2}')
		if [[ "$duration_record" == *":"* ]]; then
			minute=$(echo "$duration_record" | awk -F ":" '{print $1}' \
					| sed 's/^0*//' )
			second=$(echo "$duration_record" | awk -F ":" '{print $2}' \
					| awk '{print int($1+0.5)}' | sed 's/^0*//')
			if [[ -n "$minute" ]]; then
				minute=$((minute*60))
			fi
			tag_duration=$((minute+second))
		else
			tag_duration=$(echo "$duration_record" \
							| awk '{print int($1+0.5)}')
		fi
	fi
fi

if echo "|${ext_tracker_openmpt}|" | grep -i "|${ext}|" &>/dev/null \
&& [[ -n "$xmp_bin" ]] \
&& [[ "${#openmpt123_test_result}" -gt "0" ]]; then

	# Test file
	xmp_test_result=$("$xmp_bin" --load-only "$file" 2>&1 \
					| grep "Unrecognized file format")

	if [[ "${#xmp_test_result}" = "0" ]]; then
		# Get file tags
		"$xmp_bin" --load-only "$file" &> "$temp_cache_tags"

		tag_title=$(< "$temp_cache_tags" grep "Module name" \
					| awk -F': ' '{print $NF}' | awk '{$1=$1};1')
		tag_system=$(< "$temp_cache_tags" grep "Module type" \
					| awk -F': ' '{print $NF}' | awk '{$1=$1};1')
		# Duration
		duration_record=$(< "$temp_cache_tags" grep "Duration" \
							| awk -F ":" '{print $2}')
		duration_record="${duration_record//s/}"
		if [[ "$duration_record" == *"min"* ]]; then
			minute=$(echo "$duration_record" | awk -F "min" '{print $1}' \
					| sed 's/^0*//' )
			second=$(echo "$duration_record" | awk -F "min" '{print $2}' \
					| awk '{print int($1+0.5)}' | sed 's/^0*//')
			if [[ -n "$minute" ]]; then
				minute=$((minute*60))
			fi
			tag_duration=$((minute+second))
		fi
	fi

fi
}
tag_sap() {
local ext
ext="$1"

if [[ "$ext" = "sap" ]]; then
	# Get file tags
	strings -e S "$file" | head -15 > "$temp_cache_tags"

	# file tags
	tag_artist=$(< "$temp_cache_tags" grep -i -a "AUTHOR" | awk -F'"' '$0=$2')
	if [[ "$tag_artist" = "<?>" ]]; then
		unset tag_artist
	fi
	tag_album=$(< "$temp_cache_tags" grep -i -a "NAME" | awk -F'"' '$0=$2')
	if [[ "$tag_album" = "<?>" ]]; then
		unset tag_album
	fi
fi
}
tag_sc68() {
local ext
local info68_test_result
ext="$1"

if echo "|${ext_sc68}|" | grep -i "|${ext}|" &>/dev/null \
&& [[ -n "$info68_bin" ]]; then
	# Test file
	info68_test_result=$("$info68_bin" "$file" \
						| grep "not an sc68 file")

	if [[ "${#info68_test_result}" = "0" ]]; then
		# Get file tags
		"$info68_bin" -A "$file" > "$temp_cache_tags"

		# file tags
		tag_title=$(< "$temp_cache_tags" grep -i -a title: \
					| sed 's/^.*: //' | head -1)
		if [[ -z "$tag_title" ]] \
		|| [[ "$tag_title" = "N/A" ]]; then
			unset tag_title
		fi
		tag_artist=$(< "$temp_cache_tags" grep -i -a artist: \
					| sed 's/^.*: //' | head -1)
		if [[ -z "$tag_artist" ]] \
		|| [[ "$tag_artist" = "N/A" ]]; then
			unset tag_artist
		fi
		tag_system="SC68"
	fi
fi
}
tag_sid() {
local ext
ext="$1"

if [[ "$ext" = "sid" ]] \
&& [[ -n "$xxd_bin" ]]; then
	# file tags
	tag_artist=$("$xxd_bin" -ps -s 0x36 -l 32 "$file" \
			| tr -d '[:space:]' | xxd -r -p | tr -d '\0' \
			| iconv -f latin1 -t ascii//TRANSLIT \
			| awk '{$1=$1}1')
	if [[ "$tag_artist" = "<?>" ]]; then
		unset tag_artist
	fi
	tag_album=$("$xxd_bin" -ps -s 0x16 -l 32 "$file" \
			| tr -d '[:space:]' | xxd -r -p | tr -d '\0' \
			| iconv -f latin1 -t ascii//TRANSLIT \
			| awk '{$1=$1}1')
	if [[ "$tag_album" = "<?>" ]]; then
		unset tag_album
	fi
fi
}
tag_spc() {
local ext
local spc_duration
local spc_fading
ext="$1"

if [[ "$ext" = "spc" ]] \
&& [[ -n "$xxd_bin" ]]; then
	# file tags
	tag_title=$("$xxd_bin" -ps -s 0x0002Eh -l 32 "$file" \
				| tr -d '[:space:]' | xxd -r -p | tr -d '\0')
	tag_artist=$("$xxd_bin" -ps -s 0x000B1h -l 32 "$file" \
				| tr -d '[:space:]' | xxd -r -p | tr -d '\0')
	tag_album=$("$xxd_bin" -ps -s 0x0004Eh -l 32 "$file" \
				| tr -d '[:space:]' | xxd -r -p | tr -d '\0')
	tag_frequency="32000"
	spc_duration=$(xxd -ps -s 0x000A9h -l 3 "$file" \
					| xxd -r -p | tr -d '\0')
	spc_fading=$(xxd -ps -s 0x000ACh -l 5 "$file" \
				| xxd -r -p | tr -d '\0')
	# Correction if empty, or not an integer
	if [[ -z "$spc_duration" ]] || ! [[ "$spc_duration" =~ ^[0-9]*$ ]]; then
		spc_duration="0"
	fi
	if [[ -z "$spc_fading" ]] || ! [[ "$spc_fading" =~ ^[0-9]*$ ]]; then
		spc_fading="0"
	fi
	spc_fading=$((spc_fading/1000))
	tag_duration=$((spc_duration+spc_fading))
fi
}
tag_vgm() {
local ext
ext="$1"

if echo "|${ext_vgm}|" | grep -i "|${ext}|" &>/dev/null \
&& [[ -n "$vgm_tag_bin" ]]; then
	# Get file tags
	"$vgm_tag_bin" -ShowTag8 "$file" > "$temp_cache_tags"

	# file tags
	tag_title=$(sed -n 's/Track Title:/&\n/;s/.*\n//p' "$temp_cache_tags" \
				| awk '{$1=$1}1')
	tag_artist=$(sed -n 's/Composer:/&\n/;s/.*\n//p' "$temp_cache_tags" \
				| awk '{$1=$1}1')
	tag_album=$(sed -n 's/Game Name:/&\n/;s/.*\n//p' "$temp_cache_tags" \
				| awk '{$1=$1}1')
	tag_system=$(sed -n 's/System:/&\n/;s/.*\n//p' "$temp_cache_tags" \
				| awk '{$1=$1}1')
fi
}
tag_vgmstream() {
local ext
local vgmstream_test_result
local sample_duration
ext="$1"

if echo "|${ext_vgmstream}|" | grep -i "|${ext}|" &>/dev/null \
	&& [[ -n "$vgmstream_cli_bin" ]]; then
	# Test file
	vgmstream_test_result=$("$vgmstream_cli_bin" -m "$file" 2>/dev/null)

	if [[ "${#vgmstream_test_result}" -gt "0" ]]; then
		# Get file tags
		"$vgmstream_cli_bin" -m "$file" > "$temp_cache_tags"

		# file tags
		tag_system=$(sed -n 's/encoding:/&\n/;s/.*\n//p' "$temp_cache_tags" \
					| awk '{$1=$1}1')
		# Duration
		sample_duration=$(< "$temp_cache_tags" grep "play duration:" \
							| awk '{print $3}')
		tag_frequency=$(< "$temp_cache_tags" grep "sample rate:" \
						| awk '{print $3}')
		tag_duration=$(echo "scale=4;$sample_duration/$tag_frequency" \
							| bc | awk '{print int($1+0.5)}')
	fi
fi
}
tag_xmp() {
local ext
local minute
local second
ext="$1"

if echo "|${ext_xmp}|" | grep -i "|${ext}|" &>/dev/null \
	&& [[ -n "$xmp_bin" ]]; then
	# Get file tags
	"$xmp_bin" --load-only "$file" &> "$temp_cache_tags"

	tag_title=$(< "$temp_cache_tags" grep "Module name" \
				| awk -F': ' '{print $NF}' | awk '{$1=$1};1')
	tag_system=$(< "$temp_cache_tags" grep "Module type" \
				| awk -F': ' '{print $NF}' | awk '{$1=$1};1')
	# Duration
	duration_record=$(< "$temp_cache_tags" grep "Duration" \
						| awk -F ":" '{print $2}')
	duration_record="${duration_record//s/}"
	if [[ "$duration_record" == *"min"* ]]; then
		minute=$(echo "$duration_record" | awk -F "min" '{print $1}' \
				| sed 's/^0*//' )
		second=$(echo "$duration_record" | awk -F "min" '{print $2}' \
				| awk '{print int($1+0.5)}' | sed 's/^0*//')
		if [[ -n "$minute" ]]; then
			minute=$((minute*60))
		fi
		tag_duration=$((minute+second))
	fi

fi
}
tag_xsf() {
local ext
ext="$1"

if echo "|${ext_xsf}|" | grep -i "|${ext}|" &>/dev/null; then
	# Get file tags
	strings -e S "$file" | sed -n '/TAG/,$p' > "$temp_cache_tags"

	# file tags
	tag_title=$(< "$temp_cache_tags" grep -i -a title= | awk -F'=' '$0=$NF')
	tag_artist=$(< "$temp_cache_tags" grep -i -a artist= | awk -F'=' '$0=$NF')
	tag_album=$(< "$temp_cache_tags" grep -i -a game= | awk -F'=' '$0=$NF')
	tag_duration=$(< "$temp_cache_tags" grep -i -a length= | awk -F'=' '$0=$NF' \
					| awk -F '.' 'NF > 1 { printf "%s", $1; exit } 1' \
					| awk -F":" '{ print ($1 * 60) + $2 }' \
					| tr -d '[:space:]')
fi
}

# tag 2 db
main() {
local ext
local vgm_tested
local vgm_added
local vgm_updated
local vgm_removed

vgm_tested="0"
vgm_added="0"
vgm_updated="0"
vgm_removed="0"

for file in "${lst_vgm[@]}"; do

	# id tags
	tag_path="$file"
	tag_size=$(wc -c "$file" | awk '{print $1;}')
	tag_timestamp=$(date -r "$file" "+%s")
	tag_id=$(echo "${tag_path}${tag_size}${tag_timestamp}" \
				| sha256sum | awk '{print $1;}')
	add_id_lst+=( "$tag_id" )

	# If id not exist & no force remove
	if ! [[ ${dbquery_id_lst[*]} =~ $tag_id ]] \
	  && [[ -z "$id_forced_remove" ]]; then

		# For test ext
		ext="${file##*.}"
		ext="${ext,,}"

		# file tags
		tag_openmpt "$ext"
		tag_sid "$ext"
		tag_sc68 "$ext"
		tag_sap "$ext"
		tag_spc "$ext"
		tag_vgm "$ext"
		tag_vgmstream "$ext"
		tag_xmp "$ext"
		tag_xsf "$ext"

		# Add missing tags
		tag_default "$file"

		# Tag type of file
		tag_type="${ext^^}"
		# date added in db
		tag_add_date=$(date "+%s")

		# Force tag option
		tag_force

		# Add in db
		db_add

		# For print
		vgm_added=$(( vgm_added + 1 ))

	# If id exist & force tag & no force remove
	elif [[ ${dbquery_id_lst[*]} =~ $tag_id ]] \
	  && [[ "$tag_forced" = "1" ]] \
	  && [[ -z "$id_forced_remove" ]]; then

		tag_force
		db_force_update_album "$tag_id"
		db_force_update_artist "$tag_id"
		db_force_update_system "$tag_id"
		db_force_update_stitle "$tag_id"
		db_force_update_etitle "$tag_id"

		# For print
		if [[ "$vgm_updated_true" = "1" ]]; then
			vgm_updated=$(( vgm_updated + 1 ))
		fi

	# If id exist & force remove
	elif [[ ${dbquery_id_lst[*]} =~ $tag_id ]] \
	  && [[ "$id_forced_remove" = "1" ]]; then

		db_remove

		# For print
		vgm_removed=$(( vgm_removed + 1 ))

	fi

	# For print
	vgm_tested=$(( vgm_tested + 1 ))

	# Print
	echo "vgmfdb"
	tput bold sitm
	echo -e " Files tested        \u2933 $vgm_tested"/"${#lst_vgm[@]}"
	echo -e " Files added to db   \u2933 $vgm_added"
	echo -e " Files updated in db \u2933 $vgm_updated"
	echo -e " Files removed in db \u2933 $vgm_removed"
	tput sgr0
	# Cursor up 5 lines
	if [[ "$vgm_tested" != "${#lst_vgm[@]}" ]]; then
		printf "\033[5A"
	fi

	# Reset
	tag_reset

done
}

# Trap
trap 'kill' INT TERM SIGHUP

# Paths
export PATH=$PATH:/home/$USER/.local/bin
vgmfdb_config_dir="/home/$USER/.config/vgmfdb"
vgmfdb_database="/home/$USER/.config/vgmfdb/vgm.db"
temp_cache_tags=$(mktemp)

# Default in db
tag_forced="0"

# Arguments
while [[ $# -gt 0 ]]; do
	vgmfdb_arg="$1"
	case "$vgmfdb_arg" in
		-h|--help)
			usage
			exit
		;;
		--get_current_tags)
			get_current_tags="1"
		;;
		-i|--input)
			shift
			input_dir+=( "$1" )
			for input in "${input_dir[@]}"; do
				if ! [[ -d "$input" || -f "$input" ]]; then
					echo_error "vgmfdb was breaked."
					echo_error "\"$input\" does not exist."
					exit
				fi
			done
		;;
		--id_forced_remove)
			id_forced_remove="1"
		;;
		--tag_forced_album)
			shift
			tag_forced_album="$1"
			if [[ -z "$tag_forced_album" ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "Album name must be filled."
				exit
			else
				tag_forced="1"
			fi
		;;
		--tag_forced_artist)
			shift
			tag_forced_artist="$1"
			if [[ -z "$tag_forced_artist" ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "Artist name must be filled."
				exit
			else
				tag_forced="1"
			fi
		;;
		--tag_forced_system)
			shift
			tag_forced_system="$1"
			if [[ -z "$tag_forced_system" ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "System name must be filled."
				exit
			else
				tag_forced="1"
			fi
		;;
		--tag_forced_etitle)
			shift
			tag_forced_etitle="$1"
			if [[ -z "$tag_forced_etitle" ]] \
			|| ! [[ "$1" =~ ^[0-9]*$ ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "A positive integer must be filled."
				exit
			else
				tag_forced="1"
			fi
		;;
		--tag_forced_stitle)
			shift
			tag_forced_stitle="$1"
			if [[ -z "$tag_forced_stitle" ]] \
			|| ! [[ "$1" =~ ^[0-9]*$ ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "A positive integer must be filled."
				exit
			else
				tag_forced="1"
			fi
		;;
		--input_filter_type)
			shift
			input_filter_type="$1"
			if [[ -z "$input_filter_type" ]]; then
				echo_error "vgmfdb was breaked."
				echo_error "Type of file (extension) must be filled."
				exit
			fi
		;;
		*)
			usage
			exit
		;;
	esac
	shift
done

ext_adlib="adl|amd|bam|cff|cmf|d00|dfm|ddt|dmo|dtm|got|hsc|hsq|imf|laa|ksm|m|mdi|mtk|rad|rol|sdb|sqx|wlf|xms|xsm"
ext_c64="sid|prg"
ext_sc68="sc68|snd|sndh"
ext_sap="sap"
ext_spc="spc"
ext_tracker_openmpt="it|mod|mo3|mptm|s3m|stm|stp|plm|umx|xm"
ext_tracker_uade="aam|abk|ahx|amc|aon|ast|bss|bp|bp3|cm|cus|dm|dm2|dmu|dss|dw|ea|ex|gmc|hot|fc13|fc14|med|mug|np3|okt|pru2|rk|s7g|sfx|smus|soc|p4x|tiny|tw"
ext_various="ay|ams|dmf|dtt|hvl|mdx|mid|rmt|s98|sap|v2m|vt2|vtx|xrns|ym"
ext_vgm="vgm|vgz"
ext_vgmstream_0_c="22k|8svx|acb|acm|ad|ads|adp|adpcm|adx|aix|akb|asf|apc|at3|at9|awb|bcstm|bcwav|bfstm|bfwav|bik|brstm|bwav|cfn|ckd|cmp|csb|csmp|cps"
ext_vgmstream_d_n="dsm|dsp|dvi|fsb|gcm|genh|h4m|hca|hps|ifs|imc|int|isd|ivs|kma|kvs|lac3|lbin|lmp3|logg|lopus|lstm|lwav|mab|mca|mic|msf|mus|musx|nlsd|nop|npsf"
ext_vgmstream_o_z="oma|ras|rsd|rsnd|rws|sad|scd|sfx|sgd|snd|ss2|str|strm|svag|p04|p16|pcm|psb|thp|trk|trs|txtp|ulw|vag|vas|vgmstream|voi|wem|xa|xai|xma|xnb|xwv"
ext_vgmstream="${ext_vgmstream_0_c}|${ext_vgmstream_d_n}|${ext_vgmstream_o_z}"
ext_xmp="669|amf|dbm|digi|dsm|dsym|far|gz|mdl|musx|psm"
ext_xsf="2sf|dsf|gsf|psf|psf2|mini2sf|minigsf|minipsf|minipsf2|minissf|miniusf|minincsf|ncsf|ssf|usf"
ext_zx_spectrum="asc|psc|pt1|pt2|pt3|sqt|stc|stp|tap|zxs"
ext_all_raw="${ext_adlib}| \
			 ${ext_c64}| \
			 ${ext_sc68}| \
			 ${ext_sap}| \
			 ${ext_spc}| \
			 ${ext_tracker_openmpt}| \
			 ${ext_tracker_uade}| \
			 ${ext_various}| \
			 ${ext_vgm}| \
			 ${ext_vgmstream}| \
			 ${ext_xmp}| \
			 ${ext_xsf}| \
			 ${ext_zx_spectrum}"
ext_all=$(echo "${ext_all_raw//[[:blank:]]/}" | tr -s '|')

config
bin
db_create
search_vgm
db_id
main
db_purge
db_get_current_tags

kill
