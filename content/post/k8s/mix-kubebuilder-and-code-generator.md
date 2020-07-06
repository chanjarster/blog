---
title: "混合kubebuilder与code generator编写CRD"
date: 2020-07-01T15:35:11+08:00
tags: ["k8s"]
author: "颇忒脱"
---

<!--more-->

使用[Kubebuilder][1]+[k8s.io/code-generator][3]编写CRD。

本项目代码在 [这里][2]。

## 概览

和[k8s.io/code-generator][3]类似，是一个码生成工具，用于为你的CRD生成[kubernetes-style API][11]实现。区别在于：

* Kubebuilder不会生成informers、listers、clientsets，而code-generator会。
* Kubebuilder会生成Controller、Admission Webhooks，而code-generator不会。
* Kubebuilder会生成manifests yaml，而code-generator不会。
* Kubebuilder还带有一些其他便利性设施。

Resource + Controller = Operator，因此你可以利用Kubebuilder编写你自己的Operator。

如果你不想做Operator，如果你不会直接or间接生成Pod，只是想存取CRD（把K8S当作数据库使用）。那你可以使用Kubebuilder生成CRD和manifests yaml，再使用code-generator生成informers、listers、clientsets。

本文讲的就是这个方法。

## 准备工作：安装Kubebuilder

参考[这里][4]安装kubebuilder。

## 第一步：初始化项目

```bash
MODULE=example.com/foo-controller
go mod init $MODULE
kubebuilder init --domain example.com
kubebuilder edit --multigroup=true
```

会生成以下文件：

```txt
.
├── Dockerfile
├── Makefile
├── PROJECT
├── bin
│   └── manager
├── config
│   ├── certmanager
│   ├── default
│   ├── manager
│   ├── prometheus
│   ├── rbac
│   └── webhook
├── hack
│   └── boilerplate.go.txt
└── main.go
```

## 第二步：生成Resource和manifests

```bash
kubebuilder create api --group webapp --version v1 --kind Guestbook
Create Resource [y/n]
y
Create Controller [y/n]
n
```

会生成以下文件go代码和manifests文件：

```txt
.
├── apis
│   └── webapp
│       └── v1
│           ├── groupversion_info.go
│           ├── guestbook_types.go
│           └── zz_generated.deepcopy.go
└── config
    ├── crd
    │   ├── kustomization.yaml
    │   ├── kustomizeconfig.yaml
    │   └── patches
    │       ├── cainjection_in_guestbooks.yaml
    │       └── webhook_in_guestbooks.yaml
    ├── rbac
    │   ├── guestbook_editor_role.yaml
    │   ├── guestbook_viewer_role.yaml
    └── samples
        └── webapp_v1_guestbook.yaml
```

添加文件`apis/webapp/v1/rbac.go`，这个文件用生成RBAC manifests：

```go
// +kubebuilder:rbac:groups=webapp.example.com,resources=guestbooks,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=webapp.example.com,resources=guestbooks/status,verbs=get;update;patch

package v1
```

然后生成CRD manifests：

```bash
make manifests
```

得到：

```yaml
config
├── crd
│   └── bases
│       └── webapp.example.com_guestbooks.yaml
└── rbac
    └── role.yaml
```

**注意：**

如果你修改了`guestbook_types.go`的结构，你需要执行以下命令来更新代码和manifests：

```bash
make && make manifests
```

## 第三步：使用code-generator

### 1）准备脚本

在hack目录下准备以下文件：

```bash
.
└── hack
    ├── tools.go
    ├── update-codegen.sh
    └── verify-codegen.sh
```

新建`hack/tools.go`文件：

```go
// +build tools

package tools

import _ "k8s.io/code-generator"
```

新建`hack/update-codegen.sh`，注意修改几个变量：

* `MODULE`和`go.mod`保持一致
* `API_PKG=apis`，和`apis`目录保持一致
* `OUTPUT_PKG=generated/webapp`，生成Resource时指定的group一样
* `GROUP_VERSION=webapp:v1`和生成Resource时指定的group version对应

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# corresponding to go mod init <module>
MODULE=example.com/foo-controller
# api package
APIS_PKG=apis
# generated output package
OUTPUT_PKG=generated/webapp
# group-version such as foo:v1alpha1
GROUP_VERSION=webapp:v1

SCRIPT_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
CODEGEN_PKG=${CODEGEN_PKG:-$(cd "${SCRIPT_ROOT}"; ls -d -1 ./vendor/k8s.io/code-generator 2>/dev/null || echo ../code-generator)}

# generate the code with:
# --output-base    because this script should also be able to run inside the vendor dir of
#                  k8s.io/kubernetes. The output-base is needed for the generators to output into the vendor dir
#                  instead of the $GOPATH directly. For normal projects this can be dropped.
bash "${CODEGEN_PKG}"/generate-groups.sh "client,lister,informer" \
  ${MODULE}/${OUTPUT_PKG} ${MODULE}/${APIS_PKG} \
  ${GROUP_VERSION} \
  --go-header-file "${SCRIPT_ROOT}"/hack/boilerplate.go.txt \
  --output-base "${SCRIPT_ROOT}"
#  --output-base "${SCRIPT_ROOT}/../../.." \
```

新建`hack/verify-codegen.sh`（文件内容请看github项目）。

### 2）下载code-generator

先把[code-generator][3]下载下来，注意这里的K8S版本号，得和`go.mod`里的`k8s.io/client-go`的版本一致：

```bash
K8S_VERSION=v0.18.5
go get k8s.io/code-generator@$K8S_VERSION
go mod vendor
```

然后给`generate-groups.sh`添加可执行权限：

```bash
chmod +x vendor/k8s.io/code-generator/generate-groups.sh
```

### 3）更新依赖版本

因为code-generator用的是v0.18.5，因此要把其他的k8s库也更新到这个版本：

```bash
K8S_VERSION=v0.18.5
go get k8s.io/client-go@$K8S_VERSION
go get k8s.io/apimachinery@$K8S_VERSION
go get sigs.k8s.io/controller-runtime@v0.6.0
go mod vendor
```

### 4）生成代码

你需要修改`guestbook_types.go`文件，添加上tag `// +genclient`：

```go
// +genclient
// +kubebuilder:object:root=true

// Guestbook is the Schema for the guestbooks API
type Guestbook struct {
```

新建`apis/webapp/v1/doc.go`，注意`// +groupName=webapp.example.com`：

```go
// +groupName=webapp.example.com

package v1
```

新建`apis/webapp/v1/register.go`，code generator生成的代码需要用到它：

```go
package v1

import (
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// SchemeGroupVersion is group version used to register these objects.
var SchemeGroupVersion = GroupVersion

func Resource(resource string) schema.GroupResource {
	return SchemeGroupVersion.WithResource(resource).GroupResource()
}
```

执行`hack/update-codegen.sh`：

```bash
./hack/update-codegen.sh
```

会得到`example.com/foo-controller`目录：

```txt
example.com
└── foo-controller
    └── generated
        └── webapp
            ├── clientset
            ├── informers
            └── listers
```

移动文件：

* `example.com/foo-controller/generated`直接移出来，放到项目根下面`generated`

## 例子程序

先apply manifests yaml：

```bash
kubectl apply -f config/crd/bases/webapp.example.com_guestbooks.yaml
kubectl apply -f config/samples/webapp_v1_guestbook.yaml
```

然后执行项目的[main.go][8]。

## 参考资料

* [code-generator client-gen tag references][6]
* [kubebuilder tag references][7]
* [Kubernetes Deep Dive: Code Generation for CustomResources][9]
* [kubebuilder sample project][12]



[1]: https://github.com/kubernetes-sigs/kubebuilder
[2]: https://github.com/chanjarster/kubebuilder-mix-codegen-how-to
[3]: https://github.com/kubernetes/code-generator
[4]: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md
[5]: https://book.kubebuilder.io/quick-start.html#installation
[6]: https://github.com/kubernetes/code-generator/tree/master/cmd/client-gen
[7]: https://book.kubebuilder.io/reference/reference.html
[8]: https://github.com/chanjarster/kubebuilder-mix-codegen-how-to/blob/master/main.go
[9]: https://www.openshift.com/blog/kubernetes-deep-dive-code-generation-customresources
[11]: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md
[12]: https://github.com/kubernetes-sigs/kubebuilder/tree/master/docs/book/src/cronjob-tutorial/testdata/project