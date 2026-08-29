Templates :: {}.{
	PostInfo : {
		title : Str,
		date : Str,
		url : Str,
		tags : List(Str),
		description : Str,
	}

	html_head : Str, Str, List(Str) -> Str
	html_head = |title, meta_desc, _tags|
		"<!doctype html>"
			.concat("\n")
			.concat("<html lang='en'>")
			.concat("\n<head>\n")
			.concat("<meta charset='utf-8'>\n")
			.concat("<meta name='viewport' content='width=device-width,initial-scale=1'>\n")
			.concat("<title>${title}</title>\n")
			.concat(if meta_desc.is_empty() "" else "<meta name='description' content='${meta_desc}'>\n")
			.concat("<link rel='stylesheet' href='/site.css'>\n")
			.concat("</head>\n<body>\n")

	html_article : Str, Str, List(Str), Str -> Str
	html_article = |title, date, tags, body|
		"<article>\n<h1>${title}</h1>\n<div class='meta'>${date}</div>\n"
			.concat(List.map(tags, |t| "<span class='tag'>${t}</span>") -> Str.join_with(" "))
			.concat("\n<div class='body'>${body}</div>\n</article>\n")

	html_index_entry : PostInfo -> Str
	html_index_entry = |post|
		"<h2><a href='${post.url}'>${post.title}</a></h2>\n<p class='meta'>${post.description}</p>\n<p class='meta'>${post.date}</p>\n"

	html_index_page : List(PostInfo) -> Str
	html_index_page = |posts|
		"<!doctype html>\n<html lang='en'>\n<head>\n"
			.concat("<meta charset='utf-8'>\n")
			.concat("<meta name='viewport' content='width=device-width,initial-scale=1'>\n")
			.concat("<title>Posts</title>\n")
			.concat("<link rel='stylesheet' href='/site.css'>\n")
			.concat("</head>\n<body>\n")
			.concat("<h1>Posts</h1>\n")
			.concat(List.map(posts, html_index_entry) -> Str.join_with(""))
			.concat(html_footer(""))

	html_footer : Str -> Str
	html_footer = |heading|
		"<nav><a href='/'>Home</a></nav>\n${heading}\n<footer><a href='https://github.com/wormt/blog'>[source]</a> | Web content licensed CC BY-SA 4.0 unless otherwise noted</footer>\n</body>\n</html>"
}
