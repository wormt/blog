import pf.Html
import pf.HtmlAttributes

Badges :: {}.{
	html_badge : { src : Str, alt : Str } -> Str
	html_badge = |badge|
	    Html.render_fragment(
	        Html.img([
	            HtmlAttributes.src(badge.src),
	            HtmlAttributes.alt(badge.alt),
	            HtmlAttributes.loading("lazy"),
	        ]),
	    ).concat("\n")

	badges : List({ src : Str, alt : Str })
	badges = [
		{ src: "/badges/wormpinkbadge.webp", alt: "wormpinkbadge" },
		{ src: "/badges/stamp_pleroma_now.png", alt: "pleroma now" },
		{ src: "/badges/fedora.gif", alt: "fedora" },
		{ src: "/badges/poweredbynixos.png", alt: "poweredbynixos" },
		{ src: "/badges/grapheneos.gif", alt: "grapheneos" },
		{ src: "/badges/ed.webp", alt: "ed" },
		{ src: "/badges/vim_a.gif", alt: "vim" },
		{ src: "/badges/nocookie.gif", alt: "nocookie" },
		{ src: "/badges/nojs.gif", alt: "nojs" },
		{ src: "/badges/deadlyprogramming.gif", alt: "deadlyprogramming" },
		{ src: "/badges/seedyourtorrents.gif", alt: "seedyourtorrents" },
		{ src: "/badges/eff.png", alt: "eff" },
		{ src: "/badges/tor.gif", alt: "tor" },
		{ src: "/badges/fuckdrm.gif", alt: "fuckdrm" },
		{ src: "/badges/ipv6.gif", alt: "ipv6" },
		{ src: "/badges/lynx_enh.gif", alt: "lynx enh" },
		{ src: "/badges/monero-now.gif", alt: "monero now" },
		{ src: "/badges/mousepow.gif", alt: "mousepow" },
		{ src: "/badges/osamasux.gif", alt: "osamasux" },
		{ src: "/badges/raspberryheaven.png", alt: "raspberryheaven" },
		{ src: "/badges/sucks.gif", alt: "sucks" },
		{ src: "/badges/ffmpeg.gif", alt: "ffmpeg" },
		{ src: "/badges/ie_exploder.gif", alt: "ie exploder" },
		{ src: "/badges/bunbrowser.gif", alt: "bunbrowser" },
		{ src: "/badges/joebidenapproved.webp", alt: "joebidenapproved" },
		{ src: "/badges/assadapproved.webp", alt: "assadapproved" },
		{ src: "/badges/miku.gif", alt: "miku" },
		{ src: "/badges/konko.gif", alt: "konko" },
		{ src: "/badges/hello_kitty.gif", alt: "hello kitty" },
		{ src: "/badges/capybara.png", alt: "capybara" },
		{ src: "/badges/containsasbestos.webp", alt: "containsasbestos" },
		{ src: "/badges/banporn.gif", alt: "banporn" },
		{ src: "/badges/cc-by-sa.gif", alt: "cc by sa" },
		{ src: "/badges/agpl3pin.gif", alt: "agpl3pin" },
	]
}
