
# Outputs its first argument with the trailing slash removed
no-trailing-slash() {
	echo "$1" | sed 's@/$@@'
}

# Takes 1 URL argument, does a HEAD request and outputs only the 3-digit response code
http-status() {
	curl -sS -I "$1" | head -n 1 | sed 's/\r//' | cut -d ' ' -f 2
}

# Takes 1 URL argument, creates the database at the URL, if it doesn't exist
# Outputs status messages
create-database() {
	if [[ "200" != $(http-status "$1") ]]; then
		echo "Creating database '$1'..."
		echo $(curl -sS -X PUT "$1")
	else
		echo "Database '$1' exists; cool."
	fi
}

# Takes stdin and outputs it so it's safe to put in a JSON double-quoted string
# Also trims leading and trailing whitespace
format-json-string() {
	perl -e 'undef $/; $x=<>;' \
		-e '$x =~ s/^\s+//;' \
		-e '$x =~ s/\s+$//;' \
		-e '$x =~ s/\\/\\\\/g;' \
		-e '$x =~ s/\t/\\t/g;' \
		-e '$x =~ s/\n/\\n/g;' \
		-e '$x =~ s/"/\\"/g;' \
		-e 'print $x;'
}

# Takes 1 URL argument, gets the CouchDB _rev property of the document at the URL
doc-rev() {
	curl -sS -I "$1" | grep '^Etag' | cut -d '"' -f 2
}

# Takes 1 argument that should be a CouchDB design document URL
# Takes stdin and PUTs it to the URL
# Checks first to see if the document is modified
# Whitespace changes only MAY NOT RESULT IN AN UPDATED DESIGN DOCUMENT
submit-design() {
	URL="$1"
	DESIGN=$(cat | grep -v '"_rev": ""')

	CURRENT=$(curl -sS "$URL")
	DIFF=$(diff <(echo "$CURRENT" | perl -pe 's/\s+//g') <(echo "$DESIGN" | perl -pe 's/\s+//g'))

	if [[ -n "$DIFF" ]]; then
		echo "PUTting design document '$URL'..."
		echo "$DESIGN" | curl -sS -X PUT "$URL" -d @-
	else
		echo "Design document '$URL' is up to date."
	fi
}
