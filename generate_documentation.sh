gen_doc(){
    pandoc \
	--pdf-engine pdfroff \
	$*
}

gen_doc documentation/holdings-spec.md -o documentation/holdings-spec.pdf
