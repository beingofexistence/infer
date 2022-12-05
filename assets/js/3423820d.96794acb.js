"use strict";(self.webpackChunk=self.webpackChunk||[]).push([[2133],{3905:function(e,t,n){n.d(t,{Zo:function(){return p},kt:function(){return f}});var r=n(7294);function o(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function a(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function i(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?a(Object(n),!0).forEach((function(t){o(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):a(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function c(e,t){if(null==e)return{};var n,r,o=function(e,t){if(null==e)return{};var n,r,o={},a=Object.keys(e);for(r=0;r<a.length;r++)n=a[r],t.indexOf(n)>=0||(o[n]=e[n]);return o}(e,t);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);for(r=0;r<a.length;r++)n=a[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(o[n]=e[n])}return o}var l=r.createContext({}),s=function(e){var t=r.useContext(l),n=t;return e&&(n="function"==typeof e?e(t):i(i({},t),e)),n},p=function(e){var t=s(e.components);return r.createElement(l.Provider,{value:t},e.children)},u={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},m=r.forwardRef((function(e,t){var n=e.components,o=e.mdxType,a=e.originalType,l=e.parentName,p=c(e,["components","mdxType","originalType","parentName"]),m=s(n),f=o,d=m["".concat(l,".").concat(f)]||m[f]||u[f]||a;return n?r.createElement(d,i(i({ref:t},p),{},{components:n})):r.createElement(d,i({ref:t},p))}));function f(e,t){var n=arguments,o=t&&t.mdxType;if("string"==typeof e||o){var a=n.length,i=new Array(a);i[0]=m;var c={};for(var l in t)hasOwnProperty.call(t,l)&&(c[l]=t[l]);c.originalType=e,c.mdxType="string"==typeof e?e:o,i[1]=c;for(var s=2;s<a;s++)i[s]=n[s];return r.createElement.apply(null,i)}return r.createElement.apply(null,n)}m.displayName="MDXCreateElement"},2569:function(e,t,n){n.r(t),n.d(t,{assets:function(){return p},contentTitle:function(){return l},default:function(){return f},frontMatter:function(){return c},metadata:function(){return s},toc:function(){return u}});var r=n(7462),o=n(3366),a=(n(7294),n(3905)),i=["components"],c={title:"OCamlFormat open-source released",author:"Josh Berdine"},l=void 0,s={permalink:"/blog/2017/10/20/ocamlformat-released",source:"@site/blog/2017-10-20-ocamlformat-released.md",title:"OCamlFormat open-source released",description:"We are pleased to announce the first public release of OCamlFormat.",date:"2017-10-20T00:00:00.000Z",formattedDate:"October 20, 2017",tags:[],readingTime:.76,truncated:!1,authors:[{name:"Josh Berdine"}],nextItem:{title:"Video of @Scale2016 talk. Getting the most out of static analyzers",permalink:"/blog/2016/11/28/atscale16"}},p={authorsImageUrls:[void 0]},u=[],m={toc:u};function f(e){var t=e.components,n=(0,o.Z)(e,i);return(0,a.kt)("wrapper",(0,r.Z)({},m,n,{components:t,mdxType:"MDXLayout"}),(0,a.kt)("p",null,"We are pleased to announce the first public release of OCamlFormat."),(0,a.kt)("p",null,"OCamlFormat is a tool to automatically format ",(0,a.kt)("a",{parentName:"p",href:"https://ocaml.org/"},"OCaml")," code.\nIt follows the same basic design as refmt for\n",(0,a.kt)("a",{parentName:"p",href:"https://reasonml.github.io/"},"Reason")," code, but for OCaml. In particular, it\nworks by parsing source code using the OCaml compiler's standard parser,\ndeciding where to place comments in the parsetree, and printing the parsetree\nand comments in a uniform style."),(0,a.kt)("p",null,"At Facebook, we currently use this for the OCaml code of\n",(0,a.kt)("a",{parentName:"p",href:"https://github.com/facebook/infer"},"Infer")," to enable developers to stop thinking\nabout line breaking, indentation, parenthesization, etc., to minimize stylistic\nnit-picking during code review, and to make it as visually obvious as possible\nwhen the parser's interpretation of code does not match the programmer's. We use\nthis both with integration with editors as well as a pre-commit hook."),(0,a.kt)("p",null,"Development is taking place on\n",(0,a.kt)("a",{parentName:"p",href:"http://github.com/ocaml-ppx/ocamlformat"},"github"),". License is MIT."),(0,a.kt)("p",null,"See the ",(0,a.kt)("a",{parentName:"p",href:"http://github.com/ocaml-ppx/ocamlformat"},"github page")," for more info on\ninstallation, documentation, contributing, etc."))}f.isMDXComponent=!0}}]);