BEGIN {
    STREAM=0
	RECORDS=0
	delete LINE
}

function unquote(s) {
	gsub("\"", "", s)
	return s
}

function cb_parse_array_empty(jpath) {
	return "[]"
}

function cb_parse_object_empty(jpath) {
	return "{}"
}

function cb_parse_array_enter(jpath) {
}

function cb_parse_array_exit(jpath, status) {
}

function cb_parse_object_enter(jpath) {
}

function cb_parse_object_exit(jpath, status) {
}

function cb_append_jpath_component (jpath, component) {
	return unquote(component)
}

function cb_append_jpath_value (jpath, value) {
	v = unquote(value)
	if (jpath == "timestamp") {
		LINE["ts"] = v
		RECORDS++
	} else if (jpath == "fee_msat") {
		LINE["fee"] = -v
		RECORDS++
	} else if (jpath == "amt_out_msat") {
		LINE["amt"] = -v
		RECORDS++
	} else if (jpath == "chan_id_in") {
		LINE["cin"] = v
		RECORDS++
	} else if (jpath == "chan_id_out") {
		LINE["cout"] = v
		RECORDS++
	}
	if (RECORDS == 5) {
		printf("%s,%s,%s,%s,%s\n", LINE["ts"], LINE["cout"], LINE["cin"], LINE["amt"], LINE["fee"])
		delete LINE
		RECORDS = 0
	}
}

function cb_jpaths (ary, size) {
}

function cb_fails (ary, size) {
	for(k in ary) {
		print "cb_fails: invalid input file:", k
		print FAILS[k]
	}
}

function cb_fail1 (message) {
	print "cb_fail1: invalid input file:", FILENAME
	print message
}