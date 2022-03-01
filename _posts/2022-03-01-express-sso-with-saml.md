---
layout: default
title: Express SSO with passport-saml
date: 2022-03-01 22:49 +0800
category: nodejs saml sso
---


## 添加express-session, passport, passport-saml

```bash
yarn add passport passport-saml express-session
```

## 修改app.js

```javascript
require("regenerator-runtime/runtime");
require("dotenv").config();
const passport = require("passport"),
  SamlStrategy = require("passport-saml").Strategy;
const express = require("express");
const session = require("express-session");
const cors = require("cors");
const crypto = require("crypto");
const k8s = require("@kubernetes/client-node");
const streamBuffers = require("stream-buffers");
const fs = require("fs");
const path = require("path");
const app = express(),
  bodyParser = require("body-parser");
port = 3080;

passport.serializeUser(function (user, done) {
  done(null, user);
});
passport.deserializeUser(function (user, done) {
  done(null, user);
});

const strategy = new SamlStrategy(
  {
    entryPoint: process.env.AZURE_AUTH_SERVER_URL,
    issuer: process.env.AZURE_AUTH_APP_ID,
    callbackUrl: process.env.AZURE_AUTH_CALLBACK_URL,
    cert: process.env.AZURE_AUTH_CERTIFICATE,
  },
  (profile, done) => {
    return done(null, {
      id: profile.nameID,
    });
  }
);

passport.use(strategy);

app.use(
  session({
    resave: true,
    saveUninitialized: true,
    secret: "melody hensley is my spirit animal",
  })
);


app.use(passport.initialize());
app.use(passport.session());

app.get(
  "/auth/saml",
  passport.authenticate("saml", { failureRedirect: "/", failureFlash: true })
);

app.post(
  "/auth/saml/callback",
  bodyParser.urlencoded({ extended: false }),
  passport.authenticate("saml", { failureRedirect: "/", failureFlash: true }),
  (req, res) => res.redirect("/")
);

function sessionValidator(req, res, next) {
  if (process.env.NODE_ENV === "production") {
    console.log("Validating session:", req.user);
    if (!req.user) {
      return res.redirect("/auth/saml");
    }
  }
  return next();
}

app.get("/", sessionValidator, (req, res) => {
  res.sendFile(path.join(__dirname, "../nextjs/out/index.html"));
});

app.get("/deployment", sessionValidator, (req, res) => {
  res.sendFile(path.join(__dirname, "../nextjs/out/deployment.html"));
});

app.listen(port, () => {
  console.log(`Server listening on the port::${port}`);
});

```


其中， `strategy`返回的`profile`是长这样。

![img](/images/azure_saml_profile.png)


