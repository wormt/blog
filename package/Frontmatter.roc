Frontmatter :: {
	title : Str,
	date : Str,
	tags : List(Str),
	description : Str,
}.{
	parse_frontmatter_block : Str -> Frontmatter
	parse_frontmatter_block = |block| {
		lines = Str.split_on(block, "\n")
		lines.fold({ title: "", date: "", tags: [], description: "" }, |acc, line| {
				trimmed = line.trim_start()
				match Str.split_first(trimmed, ": ") {
					Ok({ before: key, after: raw_value }) => {
						value = raw_value.trim_start()
						match key {
							"title" => { title: value, date: acc.date, tags: acc.tags, description: acc.description },
							"date" => { title: acc.title, date: value, tags: acc.tags, description: acc.description },
							"description" => { title: acc.title, date: acc.date, tags: acc.tags, description: value },
							"tags" => { title: acc.title, date: acc.date, tags: List.keep_if(Str.split_on(value, ",") |> List.map(|t| t.trim_start()), |t| !t.is_empty()), description: acc.description },
							_ => acc
						}
					}
					Err(_) => acc
				}
			})
	}

	parse_frontmatter! : Str => Frontmatter
	parse_frontmatter! = |source| {
		match Str.split_first(source, "---\n") {
			Ok(result) => {
				match Str.split_last(result.after, "---\n") {
					Ok(inner) => parse_frontmatter_block(inner.before)
					Err(_) => { title: "", date: "", tags: [], description: "" }
				}
			}
			Err(_) => { title: "", date: "", tags: [], description: "" }
		}
	}

	extract_body : Str -> Str
	extract_body = |source| {
		match Str.split_first(source, "---\n") {
			Ok(result) => {
				match Str.split_first(result.after, "---\n\n") {
					Ok(inner) => inner.after
					Err(_) => result.after
				}
			}
			Err(_) => source
		}
	}
}
