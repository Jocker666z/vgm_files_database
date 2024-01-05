#!/usr/bin/env bash
# shellcheck disable=
# vgmfdb
# Bash script for populate sqlite database with vgm
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/vgm_files_database/
# Licence : Unlicense

bin() {
local bin_name
local system_bin_location

# vgm_tag
bin_name="vgm_tag"
system_bin_location=$(command -v $bin_name)
if [[ -n "$system_bin_location" ]]; then
	vgm_tag_bin="$system_bin_location"
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
# Print stats
echo "Total duration of operation is ${SECONDS}s".

rm "$temp_cache_tags" &>/dev/null
stty sane
exit
}
usage() {
cat <<- EOF
vgmfdb - <https://github.com/Jocker666z/vgm_files_database>
Bash script for populate sqlite database with various type of vgm files.

Usage: vgmfdb [options]
                                   Without option inplace recursively add files in db.
  -h|--help                        Display this help.
  -i|--input <directory>           Target search directory.
  --tag_forced_album "text"        Force album name.
  --tag_forced_artist "text"       Force artist name.

   -i is cumulative: -i <dir0> -i <dir1> ...
   Be careful with --tag_forced, no selection = recursive action.
EOF
}

# Search files
search_vgm() {
local input_realpath
local oldIFS

oldIFS="$IFS"

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
db_purge() {
local row_removed
local input_realpath

# Regenerate db_id
db_id
# List orphan
mapfile -t clear_id_lst < <(printf '%s\n' "${dbquery_id_lst[@]}" "${add_id_lst[@]}" | sort | uniq -u)

for value in "${clear_id_lst[@]}"; do

	row_removed=$(sqlite3 "$vgmfdb_database" "SELECT path FROM vgm WHERE id = '${value}'")

	# Limit clean at the directory selected
	for input in "${input_dir[@]}"; do
		input_realpath=$(realpath "$input")
		test_path=$(echo "$row_removed" | grep "$input_realpath")
		if [[ -n "$test_path" ]]; then
			sqlite3 "$vgmfdb_database" "DELETE FROM vgm WHERE id = '${value}'"
			echo "Removed from db : $row_removed"
			continue 2
		fi
	done

done

sqlite3 "$vgmfdb_database" 'VACUUM;'
}
db_force_update_album() {
if [[ -n "$tag_forced_album" ]]; then
	local id
	local damn
	id="$1"
	# Quote sub
	damn="''"

	sqlite3 "$vgmfdb_database" "UPDATE vgm SET album = '${tag_album//\'/$damn}' WHERE id = '$id'"
	sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
fi
}
db_force_update_artist() {
if [[ -n "$tag_forced_artist" ]]; then
	local id
	local damn
	id="$1"
	# Quote sub
	damn="''"

	sqlite3 "$vgmfdb_database" "UPDATE vgm SET artist = '${tag_artist//\'/$damn}' WHERE id = '$id'"
	sqlite3 "$vgmfdb_database" "UPDATE vgm SET tag_forced = 1 WHERE id = '$id'"
fi
}

# db query
db_id() {
mapfile -t dbquery_id_lst < <(sqlite3 "$vgmfdb_database" "SELECT id FROM vgm")
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
	elif [[ "${file##*.}" = "bp" ]]; then
		tag_system="SoundMon 2.0"
	elif [[ "${file##*.}" = "cm" ]] || [[ "${file##*.}" = "rk" ]]; then
		tag_system="CustomMade"
	elif [[ "${file##*.}" = "dw" ]]; then
		tag_system="David Whittaker"
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
}
tag_vgm() {
local ext
ext="$1"

if [[ ${ext_vgm} =~ $ext ]]  \
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
	tag_frequency=""
	tag_duration=""
	tag_system=$(sed -n 's/System:/&\n/;s/.*\n//p' "$temp_cache_tags" \
				| awk '{$1=$1}1')
fi
}
tag_xsf() {
local ext
ext="$1"

if [[ ${ext_xsf} =~ $ext ]]; then
	strings -e S "$file" | sed -n '/TAG/,$p' > "$temp_cache_tags"

	tag_title=$(< "$temp_cache_tags" grep -i -a title= | awk -F'=' '$0=$NF')
	tag_artist=$(< "$temp_cache_tags" grep -i -a artist= | awk -F'=' '$0=$NF')
	tag_album=$(< "$temp_cache_tags" grep -i -a game= | awk -F'=' '$0=$NF')
	tag_frequency=""
	tag_duration=$(< "$temp_cache_tags" grep -i -a length= | awk -F'=' '$0=$NF' \
					| awk -F '.' 'NF > 1 { printf "%s", $1; exit } 1' \
					| awk -F":" '{ print ($1 * 60) + $2 }' \
					| tr -d '[:space:]')

fi
}

# tag 2 db
main() {
local ext

for file in "${lst_vgm[@]}"; do

	# id tags
	tag_path="$file"
	tag_size=$(wc -c "$file" | awk '{print $1;}')
	tag_timestamp=$(date -r "$file" "+%s")
	tag_id=$(echo "${tag_path}${tag_size}${tag_timestamp}" \
				| sha256sum | awk '{print $1;}')
	add_id_lst+=( "$tag_id" )

	# If id not exist
	if ! [[ ${dbquery_id_lst[*]} =~ $tag_id ]]; then

		# For test ext
		ext="${file##*.}"
		ext="${ext,,}"

		# Tag type of file
		tag_type="${ext^^}"

		# file tags
		tag_vgm "$ext"
		tag_xsf "$ext"
		# Add missing tags
		tag_default "$file"

		# date added in db
		tag_add_date=$(date "+%s")

		# Force tag option
		tag_force

		# Add in db
		db_add
		echo "added to db     : $tag_path"

	# If id exist & force tag
	elif [[ ${dbquery_id_lst[*]} =~ $tag_id ]] \
	  && [[ -n "$tag_forced" ]]; then

		tag_force
		db_force_update_album "$tag_id"
		db_force_update_artist "$tag_id"

	fi

	# Reset
	tag_reset

done
}

# Trap
trap 'kill' INT TERM SIGHUP

# Arguments
while [[ $# -gt 0 ]]; do
	vgmfdb_arg="$1"
	case "$vgmfdb_arg" in
		-h|--help)
			usage
			exit
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
		*)
			usage
			exit
		;;
	esac
	shift
done

# Paths
export PATH=$PATH:/home/$USER/.local/bin
vgmfdb_config_dir="/home/$USER/.config/vgmfdb"
vgmfdb_database="/home/$USER/.config/vgmfdb/vgm.db"
temp_cache_tags=$(mktemp)

# Default in db
tag_forced="0"

ext_vgm="vgm|vgz"
ext_xsf="2sf|dsf|psf|psf2|mini2sf|minipsf|minipsf2|minissf|miniusf|minincsf|ncsf|ssf|usf"
ext_all_raw="${ext_vgm}| \
			 ${ext_xsf}"
ext_all=$(echo "${ext_all_raw//[[:blank:]]/}" | tr -s '|')


config
bin
db_create
search_vgm
db_id
main
db_purge

kill
