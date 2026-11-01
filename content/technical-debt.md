---
title: A Website Built on Technical Debt
date: 2026-09-27
tags: nix, bootc, roc, java, sass, pulumi, racket
description: what this website is
---

## What this website is

Hello world. This post is an account of the decisions i made that got this site on the public internet. None of them are defensible.

A few parts of this stack were my first time using something. The HTML renderer is written in [Roc](https://roc-lang.org) which I had only heard of very recently, the certificate script was my first time using [Racket](https://racket-lang.org), and the Azure provisioning was my first time using [Pulumi](https://www.pulumi.com). The whole setup runs on a [Fedora bootc](https://docs.fedoraproject.org/en-US/bootc/) image I configured with [Nix](https://nixos.org), because its funny.

## The HTML renderer in one Roc file

The entire static site generator lives in `package/Render.roc`. That one file parses the frontmatter, holds the HTML templates, scans the content dir, and writes the pages.

Roc is a functional language with no side effects, trying to be a little like [Elm](https://elm-lang.org). Elm 2 if you will. Recently, they fearfully refactored their Rust compiler for the language into memory unsafe [Zig](https://ziglang.org), courtesy of Claude. So that is how you know its a good programming language!

I also used a typed Roc HTML library, [basic-ssg](https://github.com/lukewilliamboswell/basic-ssg), where a page is a tree of nodes instead of a pile of strings. The badge list uses it, exactly once, returning a proper `Html.Node`. Everything else is a `Str`, glued together with `.concat` like a caveman. That was just my own laziness, not a limitation of Roc.

```roc
html_head : Str, Str -> Str
html_head = |title, meta_desc|
	"<!doctype html>"
		.concat("<html lang='en'>")
		.concat("<head>")
		.concat("<title>${title}</title>")
		.concat("<link rel='stylesheet' href='/css/site.css'>")
		.concat("</head><body>")
```

This is the actual `html_head` function, trimmed. The type signature says `Str -> Str`, the whole page is string interpolation, and the type system has no opinion on whether any of it is valid HTML.

The CSS is SCSS run through sass and then lightningcss, and the output is a single minified file. A post page like this one transfers about 4 kB of HTML and 11 kB of CSS, and i haven't even set up gzip in NGINX yet! so really, <10kb.

One thing i have planned is an [Atom feed](https://datatracker.ietf.org/doc/html/rfc4287). Not quite there yet.

## Configuring Fedora bootc with Nix

The server is a Fedora bootc image configured with [nix-caliga](https://github.com/nix-caliga/nix-caliga), a project that "aims to be to bootc images what nix-darwin is to macOS". It provides NixOS-style modules that produce a container image you boot as an operating system.

```nix
{
  config = {
    caliga.os = "fedora";
    nix.enable = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/blog";
      fromImage = pkgs.dockerTools.pullImage (...);
    };

    environment.systemPackages = [ pkgs.nginx pkgs.racket-minimal ];
  };
}
```

That is what the config looks like for nix-caliga in an attrset. `environment.systemPackages` and `systemd.services` look like NixOS, but the output is a layered OCI image built on `registry.fedoraproject.org/fedora-bootc`, and the server boots that image instead of an installer.

The Nix store on a bootc system lives in an overlay. I ran into [an issue](https://github.com/nix-caliga/nix-caliga/issues/2) where the Nix database was "reverting" upgrades inside the /nix overlay's upperdir, meaning the new image would come up with a store database left over from the old image. This ended up leading to a rabbithole of trying to come up with ways to make nix work on bootc, and thankfully the author of nix-caliga has upstreamed some changes to the main branch which mean its fairly usable now.

Nix in this repo builds the renderer, the CSS, and the OCI image. In the VM, its responsible for literally everything such as NGINX config.

## ACME in Racket

The TLS certificates come from `scripts/acme.rkt`, a Racket script that runs as a systemd oneshot under racket-minimal and drops certificates into /etc/nginx/certs.

It was my first time writing Racket. The script uses geteuid & umask to keep the certificate files at 077 and acts as a wrapper around [acme-tiny](https://github.com/diafygi/acme-tiny).

```racket
(unless (zero? ((get-ffi-obj "geteuid" (ffi-lib #f) (_fun -> _int))))
  (error 'acme "Must run as root."))

(define umask! (get-ffi-obj "umask" (ffi-lib #f) (_fun _uint -> _uint)))
(umask! #o077)
```

That is libc, called directly through Racket's FFI. No shell, just Racket pulling `geteuid` and `umask` out of the C library and calling them.

It would be kinda cool to get rid of acme-tiny and maybe use openssl's c library on its own, but right now it is kinda handles stuff that acme-tiny doesn't.

## Enterprise Java with Pulumi on Azure

The VM itself is provisioned with Pulumi, in Java, with [Gradle](https://gradle.org), on Azure. All of that just provisions one virtual machine.

It was my first time using Pulumi, and I used the [Java SDK](https://www.pulumi.com/docs/languages-sdks/java/). As a result, this personal blog has an `infra/app/build.gradle`, a `settings.gradle`, and a Gradle wrapper. enterprise java to deploy a single vm in Azure that serves static files.

```java
public class App {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  public static void main(String[] args) {
    Pulumi.run(
        ctx -> {
          var config = ctx.config();

          List<String> sshAllowedSubnets =
              config.requireObject("sshAllowedSubnets", TypeShape.list(String.class));

          var mgmt = new ManagementResource();
          var network = new NetworkResource(mgmt.resourceGroup(), sshAllowedSubnets);
          var image =
              new ImageResource(
                  mgmt.resourceGroup(), config.require("vhdPath"), config.require("imageVersion"));
          var compute =
              new ComputeResource(
                  mgmt.resourceGroup(), network.outputs().nicId(), image.imageVersionId());

          mgmt.outputs().exportOutputs(ctx);
          network.outputs().exportOutputs(ctx);
          image.outputs().exportOutputs(ctx);
          compute.outputs().exportOutputs(ctx);
        });
  }
}
```

Each of those four instantiations hides a whole class of builder calls. `NetworkResource` alone is >150 lines of builders to describe a virtual network, a subnet, and a security group. I was trying to follow some of the guidelines from the book [Effective Java](https://www.informit.com/store/effective-java-9780134685991) here just for the meme.. I think its funny.

## The debt

Every part of this used the wrong tool on purpose, written here so people can easily tell i hit at least a few disorders in the DSM-5.
