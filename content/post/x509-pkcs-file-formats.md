---
title: "X.509、PKCS文件格式介绍"
author: "颇忒脱"
tags: ["java", "tls", "openssl"]
date: 2019-04-27T20:55:20+08:00
---

<!--more-->

## ASN.1 - 数据结构描述语言

引用自[Wiki][wiki-asn.1]：

> ASN.1 is a standard **interface description language** for defining **data structures** that can be serialized and deserialized in a **cross-platform** way.

也就是说ASN.1是一种用来定义数据结构的接口描述语言，它不是二进制，也不是文件格式，看下面的例子你就会明白了：

```txt
FooQuestion ::= SEQUENCE {
    trackingNumber INTEGER,
    question       IA5String
}
```

这段代码定义了FooQuestion的数据结构，下面是FooQuestion这个数据接口的某个具体的数据：

```txt
myQuestion FooQuestion ::= SEQUENCE {
    trackingNumber     5,
    question           "Anybody there?"
}
```

ASN.1用在很多地方比如下面要讲的[X.509][wiki-x.509]和[PKCS group of cryptography standards][wiki-pkcs]。

## 文件编码格式

### DER编码格式

引用自[Wiki][wiki-asn.1]：

> ASN.1 is closely associated with a set of encoding rules that specify how to represent a data structure as a series of bytes

意思是ASN.1有一套关联的编码规则，这些编码规则用来规定如何用二进制来表示数据结构，[DER][wiki-der]是其中一种。

把上面的FooQuestion的例子用DER编码则是（16进制）：

```txt
30 13 02 01 05 16 0e 41 6e 79 62 6f 64 79 20 74 68 65 72 65 3f
```

翻译过来就是：

```txt
30 — type tag indicating SEQUENCE
13 — length in octets of value that follows
  02 — type tag indicating INTEGER
  01 — length in octets of value that follows
    05 — value (5)
  16 — type tag indicating IA5String 
     (IA5 means the full 7-bit ISO 646 set, including variants, 
      but is generally US-ASCII)
  0e — length in octets of value that follows
    41 6e 79 62 6f 64 79 20 74 68 65 72 65 3f — value ("Anybody there?")
```
看到这里你应该对DER编码格式有一个比较好的认识了。

### PEM编码格式

引用自[Wiki][wiki-pem]：

> Privacy-Enhanced Mail (PEM) is a de facto file format for storing and sending cryptographic keys, certificates, and other data, based on a set of 1993 IETF standards defining "privacy-enhanced mail."

PEM是一个用来存储和发送密码学key、证书和其他数据的文件格式的事实标准。许多使用ASN.1的密码学标准（比如[X.509][wiki-x.509]和[PKCS][wiki-pkcs]）都使用DER编码，而DER编码的内容是二进制的，不适合与邮件传输（早期Email不能发送附件），因此使用PEM把二进制内容转换成ASCII码。文件内容的格式像下面这样：

```txt
-----BEGIN label-----
BASE64Encoded
-----END label-----
```

label用来区分内容到底是什么类型，下面会讲。

和PEM相关的RFC有很多，与本文内容相关的则是[RFC7468][pem-rfc7468]，这里面规定了很多label，不过要注意不是所有label都会有对应的RFC或Specification，这些label只是一种约定俗成。

PEM实际上就是把DER编码的文件的二进制内容用base64编码一下，然后加上`-----BEGIN label-----`这样的头和`-----END label-----`这样的尾，中间则是DER文件的Base64编码。

我们可以通过下面的方法验证这个结论，先生成一个RSA Private Key，编码格式是PEM格式：

```bash
openssl genrsa -out key.pem
```

查看一下文件内容，可以看到label是`RSA PRIVATE KEY`：

```txt
-----BEGIN RSA PRIVATE KEY-----
BASE64Encoded
-----END RSA PRIVATE KEY-----
```

然后我们把PEM格式转换成DER格式：

```bash
openssl rsa -in key.pem -outform der -out key.der
```

如果你这个时候看一下文件内容会发现都是二进制。然后我们把DER文件的内容Base64一下，会看到内容和PEM文件一样（忽略头尾和换行）：

```bash
base64 -i key.der -o key.der.base64
```

## 证书、密码学Key格式

上面讲到的PEM是对证书、密码学Key文件的一种编码方式，下面举例这些证书、密码学Key文件格式：

### X.509证书

引用自[Wiki][wiki-x.509] ：

> In cryptography, **X.509** is a standard defining the format of public key certificates. X.509 certificates are used in many Internet protocols, including TLS/SSL, which is the basis for HTTPS, the secure protocol for browsing the web.

X.509是一个[Public Key Certificates][wiki-pub-key-cert]的格式标准，TLS/SSL使用它，TLS/SSL是HTTPS的基础所以HTTPS也使用它。而所谓[Public Key Certificates][wiki-pub-key-cert]又被称为**Digital Certificate** 或 **Identity Certificate**。

> An X.509 certificate contains a public key and an identity (a hostname, or an organization, or an individual), and is either signed by a certificate authority or self-signed.

一个X.509 Certificate包含一个Public Key和一个身份信息，它要么是被CA签发的要么是自签发的。

下面这种张图就是一个X.509 Certificate：

![][wiki-pub-key-cert-img]

事实上X.509 Certificate这个名词通常指代的是IETF的PKIX Certificate和CRL Profile，见[RFC5280][x.509-rfc5280]。所以当你看到PKIX Certificate字样的时候可以认为就是X.509 Certificate。

### PKCS系列

引用自[Wiki][wiki-pkcs]：

> In cryptography, **PKCS** stands for "Public Key Cryptography Standards"

前面提到的X.509是定义Public Key Certificates的格式的标准，看上去和PKCS有点像，但实际上不同，PKCS是Public Key密码学标准。此外[Public-Key Cryptography][wiki-pub-key-crypto]虽然名字看上去只涉及Public Key，实际上也涉及Priviate Key，因此PKCS也涉及Private Key。

PKCS一共有15个标准编号从1到15，这里只挑讲PKCS #1、PKCS #8、PKCS #12。

### PKCS #1

PKCS #1，RSA Cryptography Standard，定义了RSA Public Key和Private Key数学属性和格式，详见[RFC8017][pkcs1-rfc8017]。

### PKCS #8

PKCS #8，Private-Key Information Syntax Standard，用于加密或非加密地存储Private Certificate Keypairs（不限于RSA），详见[RFC5858][pkcs8-rfc5958]。

### PKCS #12

PKCS #12定义了通常用来存储Private Keys和Public Key Certificates（例如前面提到的X.509）的文件格式，使用基于密码的对称密钥进行保护。注意上述Private Keys和Public Key Certificates是复数形式，这意味着PKCS #12文件实际上是一个Keystore，PKCS #12文件可以被用做[Java Key Store][wiki-jks]（JKS），详见[RFC7292][pkcs12-rfc7292]。

如果你用自己的CA所签发了一个证书，运行下列命令可以生成PKCS #12 keystore：

```bash
openssl pkcs12 -export \
  -in <cert> \
  -inkey <private-key> \
  -name my-cert \
  -caname my-ca-root \
  -CAfile <ca-cert> \
  -chain
  -out <pkcs-file>
```

PKCS #12一般不导出PEM编码格式。

## PEM格式速查

当你不知道你的PEM文件内容是什么格式的可以根据下面查询。

### X.509 Certificate

[RFC7468 - Textual Encoding of Certificates][pem-rfc7468-1]

```txt
-----BEGIN CERTIFICATE-----
BASE64Encoded
-----END CERTIFICATE-----
```

### X.509 Certificate Subject Public Key Info

[RFC7468 - Textual Encoding of Subject Public Key Info][pem-rfc7468-2]

```txt
-----BEGIN PUBLIC KEY-----
BASE64Encoded
-----END PUBLIC KEY-----
```

### PKCS #1 Private Key

没有RFC或权威Specification，该格式有时候被称为traditional format、SSLeay format（见[SO][so-pkcs1]）

```txt
-----BEGIN RSA PRIVATE KEY-----
BASE64Encoded
-----END RSA PRIVATE KEY-----
```

### PKCS #1 Public Key

同上没有RFC或权威Specification

```txt
-----BEGIN RSA PUBLIC KEY-----
BASE64Encoded
-----END RSA PUBLIC KEY-----
```

### PKCS #8 Unencrypted Private Key

[RFC7468 - One Asymmetric Key and the Textual Encoding of PKCS #8 Private Key Info][pem-rfc7468-3]

```txt
-----BEGIN PRIVATE KEY-----
BASE64Encoded
-----END PRIVATE KEY-----
```

### PKCS #8 Encrypted Private Key

[RFC7468 - Textual Encoding of PKCS #8 Encrypted Private Key Info][pem-rfc7468-4]

```txt
-----BEGIN ENCRYPTED PRIVATE KEY-----
BASE64Encoded
-----END ENCRYPTED PRIVATE KEY-----
```

## Private Key操作命令

### 生成

**生成PKCS #1格式的RSA Private Key**

```bash
openssl genrsa -out private-key.p1.pem 2048
```

### 转换

**PKCS #1 -> Unencrypted PKCS #8**

```bash
openssl pkcs8 -topk8 -in private-key.p1.pem -out private-key.p8.pem -nocrypt
```

**PKCS #1 -> Encrypted PKCS #8**

```bash
openssl pkcs8 -topk8 -in private-key.p1.pem -out private-key.p8.pem
```

过程中会让你输入密码，你至少得输入4位，所以PKCS #8相比PKCS #1更安全。

**PKCS #8 -> PKCS #1**

```bash
openssl rsa -in private-key.p8.pem -out private-key.p1.pem
```

如果这个PKCS #8是加密的，那么你得输入密码。

## Public Key操作命令

### 从PKCS #1/#8提取

提取指的是从Private Key中提取Public Key，`openssl rsa`同时支持PKCS #1和PKCS #8的RSA Private Key，唯一的区别是如果PKCS #8是加密的，会要求你输入密码。

**提取X.509格式RSA Public Key**

```bash
openssl rsa -in private-key.pem -pubout -out public-key.x509.pem
```

**提取PKCS #1格式RSA Public Key**

```bash
openssl rsa -in private-key.pem -out public-key.p1.pem -RSAPublicKey_out
```

### 从X.509证书提取

```bash
openssl x509 -in cert.pem -pubkey -noout > public-key.x509.pem
```

### 转换

**X.509 RSA Public Key -> PKCS #1 RSA Public Key**

```bash
openssl rsa -pubin -in public-key.x509.pem -RSAPublicKey_out -out public-key.p1.pem
```

**PKCS #1 RSA Public Key -> X.509 RSA Public Key**

```bash
openssl rsa -RSAPublicKey_in -in public-key.p1.pem -pubout -out public-key.x509.pem
```

## 参考资料

* [OpenSSL Cookbook][openssl-cookbook]，一本免费介绍OpenSSL的电子书
* [PKCS #1, PKCS #8, X.509][pkcs1-pkcs8-x509]，提供了很多格式转换的例子


[wiki-asn.1]: https://en.wikipedia.org/wiki/Abstract_Syntax_Notation_One
[pem-rfc1421]: https://tools.ietf.org/html/rfc1421
[pem-rfc7468]: https://tools.ietf.org/html/rfc7468
[wiki-der]: https://en.wikipedia.org/wiki/X.690#DER_encoding
[wiki-x.509]: https://en.wikipedia.org/wiki/X.509
[wiki-pkcs]: https://en.wikipedia.org/wiki/PKCS
[wiki-pem]: https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail
[wiki-pub-key-cert]: https://en.wikipedia.org/wiki/Public_key_certificate
[wiki-pub-key-cert-img]: https://upload.wikimedia.org/wikipedia/commons/0/01/Client_and_Server_Certificate.png
[x.509-rfc5280]: https://tools.ietf.org/html/rfc5280
[wiki-pub-key-crypto]: https://en.wikipedia.org/wiki/Public-key_cryptography
[pkcs1-rfc8017]: https://tools.ietf.org/html/rfc8017
[pem-rfc7468-1]: https://tools.ietf.org/html/rfc7468#section-5.1
[pem-rfc7468-2]: https://tools.ietf.org/html/rfc7468#section-13
[pem-rfc7468-3]: https://tools.ietf.org/html/rfc7468#section-10
[pem-rfc7468-4]: https://tools.ietf.org/html/rfc7468#section-11
[pkcs8-rfc5958]: https://tools.ietf.org/html/rfc5958
[pkcs12-rfc7292]: https://tools.ietf.org/html/rfc7292
[wiki-jks]: https://en.wikipedia.org/wiki/Keystore
[openssl-cookbook]: https://www.feistyduck.com/library/openssl-cookbook/
[so-pkcs1]: https://crypto.stackexchange.com/a/47433
[pkcs1-pkcs8-x509]: https://blog.ndpar.com/2017/04/17/p1-p8/

