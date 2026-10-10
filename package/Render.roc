# Copyright (C) 2026  wormt <209373679+wormt@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

app [main!] { pf: platform "https://github.com/lukewilliamboswell/basic-ssg/releases/download/0.12.0/2C2pqQg55Sm4Y12imgSpdQi9bRiUeCbDGxF7puKrLqup.tar.zst" }

import pf.Path
import pf.OsStr
import pf.SSG
import pf.Html
import pf.HtmlAttributes

## Render

render_page! : SSG.Page, Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..others])
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

	page_html = html_head(fm.title, meta_desc)
		.concat(html_article(fm.title, fm.date, tags_list, body_html))

	SSG.write_file!({
		output_dir: output_dir,
		output_path: output_path,
		content: page_html,
	})
}

collect_metadata! : List(SSG.Page) => Try(List(PostInfo), [ReadError(Str), ParseError(Str), ..others])
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
		},
	)
}

render_index_page! : List(PostInfo), Path.Path => Try({}, [WriteError(Str), ..others])
render_index_page! = |posts, output_dir| {
	output_path = Path.join(Path.unix("posts"), "index.html")
	SSG.write_file!({
		output_dir: output_dir,
		output_path: output_path,
		content: html_index_page(posts),
	})
}

render_home_page! : List(PostInfo), Path.Path => Try({}, [WriteError(Str), ..others])
render_home_page! = |posts, output_dir| {
	output_path = Path.from_os_str(OsStr.from_str("index.html"))
	SSG.write_file!({
		output_dir: output_dir,
		output_path: output_path,
		content: html_home_page(posts),
	})
}

render_all! : List(SSG.Page), Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..others])
render_all! = |pages, output_dir| {
	metadata = collect_metadata!(pages)?
	render_home_page!(List.take_first(metadata, 5), output_dir)?
	render_index_page!(metadata, output_dir)?
	render_individual_pages!(pages, output_dir)
}

render_individual_pages! : List(SSG.Page), Path.Path => Try({}, [ReadError(Str), ParseError(Str), WriteError(Str), ..others])
render_individual_pages! = |pages, output_dir|
	match pages {
		[] => Ok({})
		[page, .. as rest] => {
			render_page!(page, output_dir)?
			render_individual_pages!(rest, output_dir)
		}
	}

main! : List(OsStr) => Try({}, [Exit(I32), PagesError(Str), ReadError(Str), ParseError(Str), WriteError(Str), ..others])
main! = |args|
	match args.drop_first(1) {
		[input_dir_arg, output_dir_arg] => {
			input_dir = Path.from_os_str(input_dir_arg)
			output_dir = Path.from_os_str(output_dir_arg)

			pages = SSG.markdown_pages!(input_dir)?
			render_all!(pages, output_dir)?
			Ok({})
		}
		_ => Err(Exit(1))
	}

## Frontmatter

Metadata : {
	title : Str,
	date : Str,
	tags : List(Str),
	description : Str,
}

parse_frontmatter_block : Str -> Metadata
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

parse_frontmatter! : Str => Metadata
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

## Templates

PostInfo : {
	title : Str,
	date : Str,
	url : Str,
	tags : List(Str),
	description : Str,
}

html_head : Str, Str -> Str
html_head = |title, meta_desc|
	"<!doctype html>"
		.concat("<html lang='en'>")
		.concat("<head>")
		.concat("<meta charset='utf-8'>")
		.concat("<meta name='viewport' content='width=device-width,initial-scale=1'>")
		.concat("<title>${title}</title>")
		.concat(if meta_desc.is_empty() "" else "<meta name='description' content='${meta_desc}'>")
		.concat("<link rel='stylesheet' href='/css/site.css'>")
		.concat("</head><body>")
		.concat("<nav><a href='/'>Home</a></nav>")

html_article : Str, Str, List(Str), Str -> Str
html_article = |title, date, tags, body|
	"<article>\n<h1>${title}</h1>\n<div class='meta'>${date}</div>\n"
		.concat(List.map(tags, |t| "<span class='tag'>${t}</span>") -> Str.join_with(" "))
		.concat("\n<div class='body'>${body}</div>\n</article>\n")
		.concat(html_footer())

html_index_entry : Str, PostInfo -> Str
html_index_entry = |cls, post| {
	class_attr = if cls.is_empty() "" else " class='${cls}'"
	"<h2${class_attr}><a href='${post.url}'>${post.title}</a></h2>\n<p class='meta'>${post.description}</p>\n<p class='meta'>${post.date}</p>\n"
}

html_index_page : List(PostInfo) -> Str
html_index_page = |posts|
	html_head("Posts", "")
		.concat("<h1>Posts</h1>\n")
		.concat(List.map(posts, |p| html_index_entry("", p)) -> Str.join_with(""))
		.concat(html_footer())

html_home_page : List(PostInfo) -> Str
html_home_page = |posts|
	"<!doctype html>\n<html lang='en'>\n<head>\n"
		.concat("<meta charset='utf-8'>\n")
		.concat("<meta name='viewport' content='width=device-width,initial-scale=1'>\n")
		.concat("<title>brainworm.homes</title>\n")
		.concat("<link rel='stylesheet' href='/css/base.css'>\n")
		.concat("<link rel='stylesheet' href='/css/home.css'>\n")
		.concat("</head>\n<body>\n")
		.concat("<nav><a href='/'>Home</a> <a href='/posts/'>Posts</a></nav>\n")
		.concat("<main class='home'>\n")
		.concat("<h1>brainworm.homes</h1>\n")
		.concat("<p class='meta'>hi, i'm wormt.</p>\n")
		.concat("<div class='columns'>\n")
		.concat(home_about_section())
		.concat(home_contact_section())
		.concat("</div>\n")
		.concat("<div class='columns-rev'>\n")
		.concat("<section id='posts'>\n<h2>recent posts</h2>\n")
		.concat(List.map(posts, |p| html_index_entry("post-entry", p)) -> Str.join_with(""))
		.concat("<p><a href='/posts/'>all posts →</a></p>\n")
		.concat("</section>\n")
		.concat(home_fetch_section())
		.concat("</div>\n")
		.concat(home_badges_section())
		# .concat(home_webring_section())
		.concat("</main>\n")
		.concat(html_footer())

home_about_section = ||
	"<section id='about'>\n<h2>about</h2>\n"
		.concat("<p>hi, im wormt.</p>\n")
		.concat("<p>I touch computers sometimes.</p>\n")
		.concat("<p>This website is built by a blog generator I wrote. Roc lang is used for HTML, Dart Sass for CSS, Nix+Fedora bootc for the OS, and Java+Pulumi for deploying the bootc image to Azure. There is also a script written in Racket for SSL certificate management.</p>\n")
		.concat("</section>\n")

home_contact_section = ||
	"<section id='contact'>\n<h2>contact</h2>\n<ul>\n"
	.concat("<li>email: amysj3 <AT> outlook [d0t] com <a href='https://keys.openpgp.org/search?q=amysj3%40outlook.com'>[PGP]</a></li>\n</li>\n")
	.concat("<li>signal: <a href='sgnl://signal.me/#eu/wHd5AQFhcfg2lIZytRybPCT4TdfMhvwG7Ctbaz0_ZDn2N_XURKJLIr20fH02v3IM'>hyphen.99</a></li>\n")
	.concat("<li>irc: l0b0t0my</li>\n</ul>\n")
	.concat("<p class='wrap'><a href='https://age-encryption.org'>age</a>: age1vruuj5f3c4mt8w3fcur2wfztf566vj0pdeta3j4tfu2p84ualpaqacdcdl</p>\n")
	.concat("<p class='wrap'>xmr: 42arGdsJssv9fVkjmnESwsFqw6jEVFVpHhXgMUESo7LP4fFTHXYzbkXNLjNsB4cefFKaHX3fWopcuSSxpsvrxoqFKxjhxr3</p>\n")
	.concat("</section>\n")

home_fetch_section = ||
	"<section id='fetch'>\n<h2>fetch</h2>\n<pre><samp><span class='fetch-art'>"
		.concat("              ==++++++++++                 OS: secureblue (powered by Fedora Atomic) x86_64\n")
		.concat("         :========++++++++++++:            Host: B650I Lightning WiFi\n")
		.concat("       ===============+++++++++++          Kernel: Linux 7.1.5-201.secureblue.1.fc44.x86_64\n")
		.concat("     ====================++++++++++        Shell: nushell 0.115.1\n")
		.concat("   :=============#%@@@%=====++++++++-      Terminal: ghostty 1.3.1-2.fc44\n")
		.concat("  -============%@%====%@@========+++++     DE: GNOME 50.3\n")
		.concat(" -============%@#======@@==========+++-    WM: Mutter (Wayland)\n")
		.concat(".=============%@+======@@==============.   CPU: AMD Ryzen 5 9600X (6) @ 5.49 GHz - 76.2°C\n")
		.concat("--=========+@@@@@@@@@@@@@@@%+==========-   CPU Cache (L1): 6x48.00 KiB (D), 6x32.00 KiB (I)\n")
		.concat("------=====%@@@@@@@@@@@@@@@@*===========   CPU Cache (L2): 6x1.00 MiB (U)\n")
		.concat("---------==%@@@@@@@%%@@@@@@@*===========   CPU Cache (L3): 32.00 MiB (U)\n")
		.concat(":----------%@@@@@#===+%@@@@@*==========-   GPU 1: Intel Arc B580 (0) @ 2.85 GHz - (12 GiB)\n")
		.concat(" ----------%@@@@@%===*@@@@@@*==========.   GPU 2: AMD Radeon Graphics (2) @ 2.20 GHz - (512 MiB)\n")
		.concat(" :---------%@@@@@@@@@@@@@@@@*=========-    Memory: 23.11 GiB / 30.43 GiB (76%)\n")
		.concat("  :--------%@@@@@@@@@@@@@@@@*========-     Swap (/dev/zram0): 8.00 GiB / 8.00 GiB (100%)\n")
		.concat("   :--------+##############+========:      Disk (/): 26.27 MiB / 26.27 MiB (100%) - overlay\n")
		.concat("     -------------------------====-        Disk (/etc): 84.35 GiB / 99.94 GiB (84%) - xfs\n")
		.concat("       --------------------------          Disk (/var/home): 759.60 GiB / 799.61 GiB (95%) - xfs\n")
		.concat("         .--------------------.            Disk (/var/log): 592.80 MiB / 3.94 GiB (15%) - xfs\n")
		.concat("              ------------                 Packages: 387 (brew), 76 (flatpak-user), 2160 (rpm)\n")
		.concat("</span></samp></pre>\n</section>\n")

home_badges_section = ||
	Html.render_fragment(
		Html.section(
			[HtmlAttributes.id("badges")],
			[
				Html.h2([], [Html.text("badges")]),
				Html.div(
					[HtmlAttributes.class("badge-grid")],
					List.map(badges, html_badge)
				)
			]
		)
	).concat("\n")

home_webring_section = ||
	"<section id='webring'>\n<h2>webring</h2>\n<p class='webring-nav'>\n<a href='#'>← prev</a>\n<a href='#'>some webring</a>\n<a href='#'>random</a>\n<a href='#'>next →</a>\n</p>\n</section>\n"

html_footer = ||
	Html.render_fragment(
		Html.footer(
			[],
			[
				Html.a(
					[HtmlAttributes.href("https://github.com/wormt/blog")],
					[Html.text("[source]")],
				),
				Html.text(" | Content CC BY-SA 4.0 | Site code AGPL-3.0-or-later"),
			],
		),
	).concat("\n</body>\n</html>\n")

## Badges

html_badge : { src : Str, alt : Str, href : Str } -> Html.Node
html_badge = |badge|
	Html.a(
		[HtmlAttributes.href(badge.href)],
		[
			Html.img([
				HtmlAttributes.src(badge.src),
				HtmlAttributes.alt(badge.alt),
				HtmlAttributes.loading("lazy"),
			]),
		],
	)

badges : List({ src : Str, alt : Str, href : Str })
badges = [
	{ src: "/badges/brainworm.webp", alt: "brainworm.homes", href: "https://brainworm.homes/" },
	{ src: "/badges/freerobuxextremist.webp", alt: "freerobuxextremist.com", href: "https://freerobuxextremist.com/" },
	{ src: "/badges/wormpinkbadge.webp", alt: "wormpinkbadge", href: "https://worm.pink/" },
	{ src: "/badges/stamp_pleroma_now.png", alt: "pleroma now", href: "https://pleroma.social/" },
	{ src: "/badges/servfail-88_31.png", alt: "servfail authoritative dns", href: "https://servfail.network/" },
	{ src: "/badges/fedora.gif", alt: "fedora", href: "https://fedoraproject.org/" },
	{ src: "/badges/poweredbynixos.png", alt: "poweredbynixos", href: "https://github.com/nix-caliga/nix-caliga" },
	{ src: "/badges/grapheneos.gif", alt: "grapheneos", href: "https://grapheneos.org/" },
	{ src: "/badges/ed.webp", alt: "ed", href: "https://www.gnu.org/software/ed/" },
	{ src: "/badges/vim_a.gif", alt: "vim", href: "https://www.vim.org/" },
	{ src: "/badges/nocookie.gif", alt: "nocookie", href: "https://brainworm.homes/" },
	{ src: "/badges/nojs.gif", alt: "nojs", href: "https://brainworm.homes/" },
	{ src: "/badges/deadlyprogramming.gif", alt: "deadlyprogramming", href: "https://brainworm.homes/" },
	{ src: "/badges/seedyourtorrents.gif", alt: "seedyourtorrents", href: "https://brainworm.homes/" },
	{ src: "/badges/eff.png", alt: "eff", href: "https://www.eff.org/" },
	{ src: "/badges/tor.gif", alt: "tor", href: "https://www.torproject.org/" },
	{ src: "/badges/fuckdrm.gif", alt: "fuckdrm", href: "https://www.defectivebydesign.org/" },
	{ src: "/badges/ipv6.gif", alt: "ipv6", href: "https://brainworm.homes/" },
	{ src: "/badges/lynx_enh.gif", alt: "lynx enh", href: "https://lynx.invisible-island.net/" },
	{ src: "/badges/monero-now.gif", alt: "monero now", href: "https://www.getmonero.org/" },
	{ src: "/badges/mousepow.gif", alt: "mousepow", href: "https://web.archive.org/web/20241203100136/https://ratmaxx.ing/" },
	{ src: "/badges/osamasux.gif", alt: "osamasux", href: "https://navy.com/" },
	{ src: "/badges/raspberryheaven.png", alt: "raspberryheaven", href: "https://en.wikipedia.org/wiki/Azumanga_Daioh" },
	{ src: "/badges/sucks.gif", alt: "sucks", href: "https://brainworm.homes/" },
	{ src: "/badges/ffmpeg.gif", alt: "ffmpeg", href: "https://ffmpeg.org/" },
	{ src: "/badges/ie_exploder.gif", alt: "ie exploder", href: "https://en.wikipedia.org/wiki/IEs4Linux" },
	{ src: "/badges/bunbrowser.gif", alt: "bunbrowser", href: "https://github.com/netsurf-plan9/nsport" },
	{ src: "/badges/joebidenapproved.webp", alt: "joebidenapproved", href: "https://fuckgov.org/@joebiden" },
	{ src: "/badges/assadapproved.webp", alt: "assadapproved", href: "https://files.catbox.moe/87xzfk.mp4" },
	{ src: "/badges/miku.gif", alt: "miku", href: "https://files.catbox.moe/ckg2mr.mp4" },
	{ src: "/badges/konko.gif", alt: "konko", href: "https://files.catbox.moe/iweerz.mp4" },
	{ src: "/badges/hello_kitty.gif", alt: "hello kitty", href: "https://files.catbox.moe/rj3y7h.gif" },
	{ src: "/badges/capybara.png", alt: "capybara", href: "https://github.com/looskie/capybara-api" },
	{ src: "/badges/containsasbestos.webp", alt: "containsasbestos", href: "https://brainworm.homes/" },
	{ src: "/badges/banporn.gif", alt: "banporn", href: "https://brainworm.homes/" },
	{ src: "/badges/cc-by-sa.gif", alt: "cc by sa", href: "https://creativecommons.org/licenses/by-sa/4.0/" },
	{ src: "/badges/agpl3pin.gif", alt: "agpl3pin", href: "https://www.gnu.org/licenses/agpl-3.0.html" },
]
