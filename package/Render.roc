app [main!] { pf: platform "https://github.com/lukewilliamboswell/basic-ssg/releases/download/0.10.0/26wr2c8pfpVzPv93VVQ9Y2yRQz7tder7atwNG7PvWs6e.tar.zst" }

import pf.Path
import pf.OsStr exposing [OsStr]
import pf.SSG

Frontmatter := {
    title: Str,
    date: Str,
    tags: List(Str),
    description: Str,
}

PostInfo := {
    title: Str,
    date: Str,
    url: Str,
    tags: List(Str),
    description: Str,
}

html_head : Str, Str, List(Str) => Str
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

html_article : Str, Str, List(Str), Str => Str
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
    "<nav><a href='/'>Home</a></nav>\n${heading}\n<footer>No one can be remembered</footer>\n</body>\n</html>"

parse_frontmatter_block : Str => Frontmatter
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

extract_body : Str => Str
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

render_page! : SSG.Page, Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..])
render_page! = |page, output_dir| {
    source = SSG.read_source!(page)?
    fm = parse_frontmatter!(source)
    body_str = extract_body(source)
    body_html = SSG.render_markdown!({ source_path: page.source_path, markdown: body_str })?
    meta_desc = if fm.description.is_empty() "" else fm.description
    tags_list = fm.tags

    filename_str = match page.output_path.filename() {
        Ok(fp) => match fp.to_str() {
            Ok(s) => s
            Err(_) => "default.html"
        }
        Err(_) => "default.html"
    }
    output_path = Path.join(Path.unix("posts"), filename_str)

    page_html = html_head(fm.title, meta_desc, tags_list)
        .concat(html_article(fm.title, fm.date, tags_list, body_html))
        .concat(html_footer(""))

    SSG.write_file!({
        output_dir: output_dir,
        output_path: output_path,
        content: page_html,
    })
}

collect_metadata! : List(SSG.Page) => Try(List(PostInfo), [ReadError(Str), ParseError(Str), ..])
collect_metadata! = |pages| {
    pages.fold_try!(
        [],
        |acc, page| {
            source = SSG.read_source!(page)?
            fm = parse_frontmatter!(source)
            filename_str = match page.output_path.filename() {
                Ok(fp) => match fp.to_str() {
                    Ok(s) => s
                    Err(_) => "default.html"
                }
                Err(_) => "default.html"
            }
            post_url = Str.concat("/posts/", filename_str)
            Ok(List.append(acc, { title: fm.title, date: fm.date, url: post_url, tags: fm.tags, description: fm.description }))
        }
    )
}

render_index_page! : List(PostInfo), Path.Path => Try({}, [WriteError(Str), ..])
render_index_page! = |posts, output_dir| {
    output_path = Path.from_os_str(OsStr.from_str("index.html"))
    SSG.write_file!({
        output_dir: output_dir,
        output_path: output_path,
        content: html_index_page(posts),
    })
}

render_all! : List(SSG.Page), Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..])
render_all! = |pages, output_dir| {
    metadata = collect_metadata!(pages)?
    render_index_page!(metadata, output_dir)?
    render_individual_pages!(pages, output_dir)
}

render_individual_pages! : List(SSG.Page), Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..])
render_individual_pages! = |pages, output_dir|
    match pages {
        [] => Ok({})
        [page, .. as rest] => {
            render_page!(page, output_dir)?
            render_individual_pages!(rest, output_dir)
        }
    }

main! : List(OsStr) => Try({}, [Exit(I32), PagesError(Str), ReadError(Str), ParseError(Str), WriteError(Str), ..])
main! = |args|
    match args.drop_first(1) {
        [input_dir_arg, output_dir_arg] => {
            input_dir = Path.from_os_str(input_dir_arg)
            output_dir = Path.from_os_str(output_dir_arg)

            pages = SSG.pages!(input_dir)?
            render_all!(pages, output_dir)?
            Ok({})
        }
        _ => Err(Exit(1))
    }
