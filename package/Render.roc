app [main!] { pf: platform "https://github.com/lukewilliamboswell/basic-ssg/releases/download/0.10.0/26wr2c8pfpVzPv93VVQ9Y2yRQz7tder7atwNG7PvWs6e.tar.zst" }

import pf.Path
import pf.OsStr exposing [OsStr]
import pf.SSG
import Frontmatter
import Templates

render_page! : SSG.Page, Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..])
render_page! = |page, output_dir| {
    source = SSG.read_source!(page)?
    fm = Frontmatter.parse_frontmatter!(source)
    body_str = Frontmatter.extract_body(source)
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

    page_html = Templates.html_head(fm.title, meta_desc)
        .concat(Templates.html_article(fm.title, fm.date, tags_list, body_html))

    SSG.write_file!({
        output_dir: output_dir,
        output_path: output_path,
        content: page_html,
    })
}

collect_metadata! : List(SSG.Page) => Try(List(Templates.PostInfo), [ReadError(Str), ParseError(Str), ..])
collect_metadata! = |pages| {
    pages.fold_try!(
        [],
        |acc, page| {
            source = SSG.read_source!(page)?
            fm = Frontmatter.parse_frontmatter!(source)
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

render_index_page! : List(Templates.PostInfo), Path.Path => Try({}, [WriteError(Str), ..])
render_index_page! = |posts, output_dir| {
    output_path = Path.from_os_str(OsStr.from_str("index.html"))
    SSG.write_file!({
        output_dir: output_dir,
        output_path: output_path,
        content: Templates.html_index_page(posts),
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

