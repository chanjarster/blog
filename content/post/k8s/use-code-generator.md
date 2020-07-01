---
title: "使用k8s.io/code-generator编写自定义K8S API"
date: 2020-06-30T08:57:26+08:00
tags: ["k8s"]
author: "颇忒脱"
---

<!--more-->

本项目代码在 https://github.com/chanjarster/k8s-code-gen-how-to

## 第一步：初始化项目

```bash
MODULE=example.com/foo-controller
go mod init $MODULE
```

## 第二步：定义API

新建目录`api/<group>/<version>`，这个目录下得有以下几个文件：

```bash
.
├── api
    └── foo
        └── v1alpha1
            ├── doc.go
            ├── register.go
            └── types.go
```

执行命令：

```bash
GROUP=foo
VERSION=v1alpha1
mkdir -p api/$GROUP/$VERSION
```

编写文件`api/<group>/<version>/doc.go`，注意`//+groupName=foo.example.com`，你需要视情况修改：

```go
// +k8s:deepcopy-gen=package
// +groupName=foo.example.com

// Package v1alpha1 is the v1alpha1 version of the API.
package v1alpha1
```

编写文件`api/<group>/<version>/types.go`，注意视情况修改类名以及相关常量，`Status`字段并非必须的：

```go
package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// These const variables are used in our custom controller.
const (
	GroupName string = "foo.example.com"
	Kind      string = "Foo"
	Version   string = "v1alpha1"
	Plural    string = "foos"
	Singluar  string = "foo"
	ShortName string = "foo"
	Name      string = Plural + "." + GroupName
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Foo is a specification for a Foo resource
type Foo struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   FooSpec   `json:"spec"`
	Status FooStatus `json:"status"`
}

// FooSpec is the spec for a Foo resource
type FooSpec struct {
	DeploymentName string `json:"deploymentName"`
	Replicas       *int32 `json:"replicas"`
}

// FooStatus is the status for a Foo resource
type FooStatus struct {
	AvailableReplicas int32 `json:"availableReplicas"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// FooList is a list of Foo resources
type FooList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata"`

	Items []Foo `json:"items"`
}
```

编写文件`api/<group>/register.go`

```go
package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

var (
	// SchemeBuilder initializes a scheme builder
	SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
	// AddToScheme is a global function that registers this API group & version to a scheme
	AddToScheme = SchemeBuilder.AddToScheme
)

// SchemeGroupVersion is group version used to register these objects.
var SchemeGroupVersion = schema.GroupVersion{
	Group:   GroupName,
	Version: Version,
}

func Resource(resource string) schema.GroupResource {
	return SchemeGroupVersion.WithResource(resource).GroupResource()
}

func addKnownTypes(scheme *runtime.Scheme) error {
	scheme.AddKnownTypes(SchemeGroupVersion,
		&Foo{},
		&FooList{},
	)
	metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
	return nil
}
```

然后添加依赖：

```bash
K8S_VERSION=v0.18.5
go get k8s.io/apimachinery@$K8S_VERSION
```

## 第三步：代码生成

### 1）准备脚本

新建目录hack，我们需要在hack目录下有以下几个文件：

```bash
.
└── hack
    ├── boilerplate.go.txt
    ├── tools.go
    ├── update-codegen.sh
    └── verify-codegen.sh
```

执行命令：

```bash
mkdir hack
touch hack/boilerplate.go.txt
```

新建`hack/tools.go`文件：

```go
// +build tools
package tools

import _ "k8s.io/code-generator"
```

新建`hack/update-codegen.sh`，注意修改几个变量`MODULE`、`API_PKG`、`OUTPUT_PKG`、`GROUP_VERSION`。注意`GROUP_VERSION`参数，它是`foo.v1alpha1`而不是`foo.example.com:v1alpha1`，因为code generator会读取我们之前写的`api/<group>/<version>`下的代码，因此得要对应上这个路径：

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# corresponding to go mod init <module>
MODULE=example.com/foo-controller
# api package
APIS_PKG=api
# generated output package
OUTPUT_PKG=generated
# group-version such as foo:v1alpha1
GROUP_VERSION=foo:v1alpha1

SCRIPT_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
CODEGEN_PKG=${CODEGEN_PKG:-$(cd "${SCRIPT_ROOT}"; ls -d -1 ./vendor/k8s.io/code-generator 2>/dev/null || echo ../code-generator)}

# generate the code with:
# --output-base    because this script should also be able to run inside the vendor dir of
#                  k8s.io/kubernetes. The output-base is needed for the generators to output into the vendor dir
#                  instead of the $GOPATH directly. For normal projects this can be dropped.
bash "${CODEGEN_PKG}"/generate-groups.sh "all" \
  ${MODULE}/${OUTPUT_PKG} ${MODULE}/${APIS_PKG} \
  ${GROUP_VERSION} \
  --go-header-file "${SCRIPT_ROOT}"/hack/boilerplate.go.txt \
  --output-base "$(dirname "${BASH_SOURCE[0]}")/.."
#  --output-base "$(dirname "${BASH_SOURCE[0]}")/../../.." \

# To use your own boilerplate text append:
#   --go-header-file "${SCRIPT_ROOT}"/hack/custom-boilerplate.go.txt
```

新建`hack/verify-codegen.sh`：

```bash
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

OUTPUT_PKG=generated
MODULE=example.com/foo-controller

SCRIPT_ROOT=$(dirname "${BASH_SOURCE[0]}")/..

DIFFROOT="${SCRIPT_ROOT}/${OUTPUT_PKG}"
TMP_DIFFROOT="${SCRIPT_ROOT}/_tmp/${OUTPUT_PKG}"
_tmp="${SCRIPT_ROOT}/_tmp"

cleanup() {
  rm -rf "${_tmp}"
}
trap "cleanup" EXIT SIGINT

cleanup

mkdir -p "${TMP_DIFFROOT}"
cp -a "${DIFFROOT}"/* "${TMP_DIFFROOT}"

"${SCRIPT_ROOT}/hack/update-codegen.sh"
echo "copying generated ${SCRIPT_ROOT}/${MODULE}/${OUTPUT_PKG} to ${DIFFROOT}"
cp -r "${SCRIPT_ROOT}/${MODULE}/${OUTPUT_PKG}"/* "${DIFFROOT}"

echo "diffing ${DIFFROOT} against freshly generated codegen"
ret=0
diff -Naupr "${DIFFROOT}" "${TMP_DIFFROOT}" || ret=$?
cp -a "${TMP_DIFFROOT}"/* "${DIFFROOT}"
if [[ $ret -eq 0 ]]
then
  echo "${DIFFROOT} up to date."
else
  echo "${DIFFROOT} is out of date. Please run hack/update-codegen.sh"
  exit 1
fi
```

### 2）下载code-generator

先把[code-generator][1]下载下来，注意这里的K8S版本号，得和前面是一致的：

```bash
K8S_VERSION=v0.18.5
go get k8s.io/code-generator@$K8S_VERSION
go mod vendor
```

然后给`generate-groups.sh`添加可执行权限：

```bash
chmod +x vendor/k8s.io/code-generator/generate-groups.sh
```

### 3）生成代码

执行`hack/update-codegen.sh`：

```bash
./hack/update-codegen.sh
```

代码会生成在`example.com/foo-controller`目录下（回忆前面的`MODULE=example.com/foo-controller`和`OUTPUT_PKG=generated`参数）：

```txt
example.com
└── foo-controller
    ├── api
    │   └── foo
    │       └── v1alpha1
    │           └── zz_generated.deepcopy.go
    └── generated
        ├── clientset
        ├── informers
        └── listers
```

移动文件：

* `zz_generated.deepcopy.go`移动到`api/<group>/<version>`下
* `example.com/foo-controller/generated`直接移出来，放到项目根下面`generated`
* 如果后面你修改了`types.go`，重新执行`./hack/update-codegen.sh`就行了。

对于生成代码的说明：

* `clientset`：用于操作`foos.foo.example.com`CRD资源
* `informers`：Informer接收来自服务器的CRD的变更事件
* `listers`：Lister提供只读的cache layer for GET和LIST请求

## 关于Controller

controller代码可以看项目的[main.go][7]。

本例子里controller读取环境变量`KUBECONFIG`来启动Clientset以及和K8S通信，这个也符合[k8s.io/client-go out-of-cluster example][8]。在实际生产环境中，可以参考[k8s.io/client-go in-cluster example][9]。

如果你想要更灵活的做法，比如当提供了`--kubeconfig`的时候采用out-of-cluster模式，否则则尝试in-cluster模式（看`/var/run/secrets/kubernetes.io/serviceaccount`），可以参考[prometheus-operator k8sutil.go][10]的做法

## 参考文档

* [Kubernetes Deep Dive: Code Generation for CustomResources][2]
* [Programming Kubernetes CRDs][3]
* [Sample Controller][4]
* [code-generator][5]
* [client-go][6]

[1]: https://pkg.go.dev/mod/k8s.io/code-generator?tab=overview
[2]: https://www.openshift.com/blog/kubernetes-deep-dive-code-generation-customresources
[3]: https://insujang.github.io/2020-02-13/programming-kubernetes-crd/
[4]: https://github.com/kubernetes/sample-controller
[5]: https://github.com/kubernetes/code-generator
[6]: https://github.com/kubernetes/client-go
[7]: https://github.com/chanjarster/k8s-code-gen-how-to/blob/master/main.go
[8]: https://github.com/kubernetes/client-go/blob/master/examples/out-of-cluster-client-configuration
[9]: https://github.com/kubernetes/client-go/blob/master/examples/in-cluster-client-configuration
[10]: https://github.com/coreos/prometheus-operator/blob/v0.40.0/pkg/k8sutil/k8sutil.go#L61-L95