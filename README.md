couch-bash-func
===============

Some Bash functions to easily talk to CouchDB from the command line.

For example, you can easily store your database framework (design docs) as an
executable or sourceable Bash script file:


	#!/bin/bash
	#
	# Schema for my couch database ("/foo").
	# Provide base URL (protocol,[user:pass@]hostname,port) as first argument (e.g. http://my.example.com:5984)
	#

	DB="foo"

	. "$(dirname $0)/couch-bash-func.sh"

	BASE=$(no-trailing-slash "$1")

	if [[ -z "$BASE" ]]; then
		echo -e "Please provide an argument of the base DB URL; e.g.\n$0 http://user:pass@ls7:5984."
		exit 1
	fi

	create-database "$BASE/$DB"

	DOC_ID="_design/foodes"
	DOC_URL="$BASE/$DB/$DOC_ID" 

	submit-design "$DOC_URL" <<DESIGN
	{
		"_id": "$DOC_ID",
		"_rev": "$(doc-rev "$DOC_URL")",

		"validate_doc_update": "$(format-json-string <<JSFUNC
			function (newDoc, oldDoc, userCtx, secObj) {
				var i, error = [];

				if (!newDoc.hasOwnProperty("user_id")
					|| !newDoc.user_id
					|| parseInt(newDoc.user_id, 10) < 67
				) {
					error.push("Document must have user_id!");
				} else if (typeof newDoc.user_id !== 'number') {
					error.push("user_id property must be a number!");
				}

				if (!newDoc.hasOwnProperty("keywords") || !isArray(newDoc.keywords)) {
					error.push("Document must have [keywords]!");
				} else {

					if (newDoc.keywords.length === 0) {
						error.push("Document must have at least one keyword!");
					}
					for (i = 0; i < newDoc.keywords.length; i++) {
						if (!newDoc.keywords[i]) {
							error.push("Keywords cannot be empty!");
							break;
						}
						if (newDoc.keywords[i].constructor !== String) {
							error.push("Keywords must be Strings!");
							break;
						}
					}
				}

				if (error.length > 0) {
					throw({ "forbidden": error.join("\n") });
				}

			}
	JSFUNC
		)",

		"views": {
			"by_user": {
				"map": "$(format-json-string <<JSFUNC
					function (doc) {
						emit(doc.user_id);
					}
	JSFUNC
				)"
			},
			"by_keyword": {
				"map": "$(format-json-string <<JSFUNC
					function (doc) {
						var i,
							l = doc.keywords.length
						;
						for (i = 0; i < l; i++) {
							emit(doc.keywords[i]);
						}
					}
	JSFUNC
				)"
			}
		}
	}
	DESIGN

	echo "Done."

