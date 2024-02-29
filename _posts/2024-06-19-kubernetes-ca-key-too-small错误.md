---
layout: default
title: Kubernetes CA_KEY_TOO_SMALL错误
date: 2024-06-19 16:00 +0800
categories: kubernetes
---

阿里云上的老集群会遇到 CA_KEY_TOO_SMALL 错误，原因是本地的`~/.kube/config`里面，客户端的证书链有问题，其中一个证书过短。

```bash
echo 'your-cluster-context-name' | xargs -I {} yq '.users.[] | select(.name == "{}").user.client-certificate-data' ~/.kube/config | base64 -d | awk '/-----BEGIN CERTIFICATE-----/{c++; if(c==2) {flag=1}} flag;' | openssl x509 -text -noout
```

就可以看到类似下面的内容，可以看到证书是通过 RSA 1024bit 加密的。

```bash
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 2155642 (0x20e47a)
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = CN, ST = ZheJiang, L = HangZhou, O = Alibaba, OU = ACS, CN = root
        Validity
            Not Before: Jan 11 07:41:00 2021 GMT
            Not After : Jan  6 07:46:47 2041 GMT
        Subject: O = cdfb96be51aef4d24acb45a3367ede299, OU = default, CN = cdfb96be51aef4d24acb45a3367ede299
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (1024 bit)
                Modulus:
                    ...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment, Key Agreement, Certificate Sign
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Authority Key Identifier:
                keyid:85:5A:FF:DD:23:CD:25:6F:58:41:6F:9E:6D:45:39:9B:58:7D:75:FF

            Authority Information Access:
                OCSP - URI:http://certs.acs.aliyun.com/ocsp

            X509v3 CRL Distribution Points:

                Full Name:
                  URI:http://certs.acs.aliyun.com/root.crl
```

这样的证书会导致 Python 包[kubernetes-client][1]连不上集群。虽然可以通过设置`urllib3`来避免这个报错，但是在`kubernetes exec/logs`的时候，还是会报错，因为`exec/logs`是用的 websockets，并没有基于`urllib3`包。

给阿里云提工单，他们提供的一个脚本解决这个问题，结果很暴力地把第二个证书删掉了。

```python
#!coding: utf-8

from base64 import b64decode, b64encode
import re
import sys

import yaml

re_cert_end = re.compile(r'-----END CERTIFICATE-----')


def convert(file_path):
    with open(file_path) as fp:
        kubeconfig = yaml.safe_load(fp.read())

    raw_old_client_cert = kubeconfig['users'][0]['user']['client-certificate-data']
    raw_new_client_cert = remove_1024_cert(raw_old_client_cert)
    new_client_cert = b64encode(raw_new_client_cert.encode('utf-8'))
    print(new_client_cert)

    kubeconfig['users'][0]['user']['client-certificate-data'] = new_client_cert.decode('utf-8')
    return yaml.safe_dump(kubeconfig)


def remove_1024_cert(encoded_cert):
    origin_certs = split_certs(b64decode(encoded_cert).decode('utf-8'))
    sorted_certs = sorted(origin_certs, key=lambda x: len(x))
    new_certs = []
    if len(sorted_certs) < 2:
        new_certs = sorted_certs
    else:
        new_certs = sorted_certs[1:]

    return '\n'.join(new_certs)


def split_certs(certs_str):
    parts = re_cert_end.split(certs_str)
    for item in parts:
        item = item.strip()
        if not item:
            continue
        yield item + '\n-----END CERTIFICATE-----'


def main():
    origin_file = sys.argv[1]
    new_file = '{}.converted.yaml'.format(origin_file)
    print('start convert {} to {}'.format(origin_file, new_file))

    new_content = convert(origin_file)
    with open(new_file, 'wb') as fp:
        fp.write(new_content.encode('utf-8'))

    print('converted {} to {}'.format(origin_file, new_file))


if __name__ == '__main__':
    main()

```

[1]: https://github.com/kubernetes-client/python/issues/1824
