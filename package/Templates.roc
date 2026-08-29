Templates :: {}.{
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
			.concat("\n")
			.concat("<html lang='en'>")
			.concat("\n<head>\n")
			.concat("<meta charset='utf-8'>\n")
			.concat("<meta name='viewport' content='width=device-width,initial-scale=1'>\n")
			.concat("<title>${title}</title>\n")
			.concat(if meta_desc.is_empty() "" else "<meta name='description' content='${meta_desc}'>\n")
			.concat("<link rel='stylesheet' href='/css/site.css'>\n")
			.concat("</head>\n<body>\n")
			.concat("<nav><a href='/'>Home</a></nav>\n")

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
			.concat("<p class='meta'>hi, i'm rat. you may know me from the fediverse.</p>\n")
			.concat("<div class='columns'>\n")
			.concat(home_about_section())
			.concat(home_contact_section())
			.concat("</div>\n")
			.concat("<section id='posts'>\n<h2>recent posts</h2>\n")
			.concat(List.map(posts, |p| html_index_entry("post-entry", p)) -> Str.join_with(""))
			.concat("<p><a href='/posts/'>all posts →</a></p>\n")
			.concat("</section>\n")
			.concat(home_fetch_section())
			.concat(home_badges_section())
			.concat(home_webring_section())
			.concat("</main>\n")
			.concat(html_footer())

	home_about_section = ||
		"<section id='about'>\n<h2>about</h2>\n"
			.concat("<p>hi, im wormt.</p>\n")
			.concat("<p>I touch computers sometimes. I'm currently working full time as a system administrator while studying computer science. I read RFCs for fun.</p>\n")
			.concat("<p>I like programming. Zig is the best programming language. Unfortunately I have to minmax Java & C++ for the time being.</p>\n")
			.concat("<p>I am familiar with a variety of tooling such as Ansible, Terraform, Pulumi, Nix, and OCI images.</p>\n")
			.concat("<p>I would like to learn more about the cloud native ecosystem, kernel dev, and consensus algorithms.</p>\n")
			.concat("<p>I listen to maidcore, black metal, snailcore, epunk, cybergrind, blackgaze, and other adjacent genres. My favorite artist is Gezebelle Gaburgably.</p>\n")
			.concat("<p>This website is built by a generator I wrote. Roc lang is used for HTML, Dart Sass for CSS, Nix+Fedora bootc for the OS, and Java+Pulumi for deploying the bootc image to Azure.</p>\n")
			.concat("</section>\n")

	home_contact_section = ||
		"<section id='contact'>\n<h2>contact</h2>\n<ul>\n"
		.concat("<li>email: amysj3 <AT> outlook [d0t] com</li>\n</li>\n")
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
		"<section id='badges'>\n<h2>badges</h2>\n<div class='badge-grid'>\n<a href='https://example.org'><img src='/media/example.webp' alt='example badge' width='88' height='31' loading='lazy' /></a>\n<img src='/media/example2.gif' alt='another badge' width='88' height='31' loading='lazy' />\n</div>\n</section>\n"

	home_webring_section = ||
		"<section id='webring'>\n<h2>webring</h2>\n<p class='webring-nav'>\n<a href='#'>← prev</a>\n<a href='#'>some webring</a>\n<a href='#'>random</a>\n<a href='#'>next →</a>\n</p>\n</section>\n"

	html_footer = ||
		"<footer><a href='https://github.com/wormt/blog'>[source]</a> | Web content licensed CC BY-SA 4.0 unless otherwise noted</footer>\n</body>\n</html>"
}
