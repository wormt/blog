# wormt blog

The plan is to generate HTML articles via roc lang's SSG library & generate CSS
with Sass. Eventually i want to implement RSS+jsonfeed support but that may
take a while.

the VM image will use nix, nginx, and some goofy way of doing ACME renewals
linking to a library's public functions rather than executing something
like certbot in the cli. i might either use common lisp+clasp for this or
zig and link to lego(or some other random thing i can find) which iirc
you are able to do these kinds of shenanigans with.

I will then deploy this to a free azure vm using pulumi's java sdk for
a maximally cursed setup. hopefully this works lmao
