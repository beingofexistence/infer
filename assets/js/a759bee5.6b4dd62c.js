"use strict";(self.webpackChunk=self.webpackChunk||[]).push([[2980],{3905:function(e,r,t){t.d(r,{Zo:function(){return s},kt:function(){return k}});var n=t(7294);function o(e,r,t){return r in e?Object.defineProperty(e,r,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[r]=t,e}function c(e,r){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);r&&(n=n.filter((function(r){return Object.getOwnPropertyDescriptor(e,r).enumerable}))),t.push.apply(t,n)}return t}function a(e){for(var r=1;r<arguments.length;r++){var t=null!=arguments[r]?arguments[r]:{};r%2?c(Object(t),!0).forEach((function(r){o(e,r,t[r])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):c(Object(t)).forEach((function(r){Object.defineProperty(e,r,Object.getOwnPropertyDescriptor(t,r))}))}return e}function l(e,r){if(null==e)return{};var t,n,o=function(e,r){if(null==e)return{};var t,n,o={},c=Object.keys(e);for(n=0;n<c.length;n++)t=c[n],r.indexOf(t)>=0||(o[t]=e[t]);return o}(e,r);if(Object.getOwnPropertySymbols){var c=Object.getOwnPropertySymbols(e);for(n=0;n<c.length;n++)t=c[n],r.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(o[t]=e[t])}return o}var u=n.createContext({}),i=function(e){var r=n.useContext(u),t=r;return e&&(t="function"==typeof e?e(r):a(a({},r),e)),t},s=function(e){var r=i(e.components);return n.createElement(u.Provider,{value:r},e.children)},p={inlineCode:"code",wrapper:function(e){var r=e.children;return n.createElement(n.Fragment,{},r)}},f=n.forwardRef((function(e,r){var t=e.components,o=e.mdxType,c=e.originalType,u=e.parentName,s=l(e,["components","mdxType","originalType","parentName"]),f=i(t),k=o,d=f["".concat(u,".").concat(k)]||f[k]||p[k]||c;return t?n.createElement(d,a(a({ref:r},s),{},{components:t})):n.createElement(d,a({ref:r},s))}));function k(e,r){var t=arguments,o=r&&r.mdxType;if("string"==typeof e||o){var c=t.length,a=new Array(c);a[0]=f;var l={};for(var u in r)hasOwnProperty.call(r,u)&&(l[u]=r[u]);l.originalType=e,l.mdxType="string"==typeof e?e:o,a[1]=l;for(var i=2;i<c;i++)a[i]=t[i];return n.createElement.apply(null,a)}return n.createElement.apply(null,t)}f.displayName="MDXCreateElement"},8259:function(e,r,t){t.r(r),t.d(r,{contentTitle:function(){return u},default:function(){return f},frontMatter:function(){return l},metadata:function(){return i},toc:function(){return s}});var n=t(7462),o=t(3366),c=(t(7294),t(3905)),a=["components"],l={title:"Resource Leak checker for .NET",description:'"resource leak" checker for .NET.'},u=void 0,i={unversionedId:"checker-dotnet-resource-leak",id:"checker-dotnet-resource-leak",title:"Resource Leak checker for .NET",description:'"resource leak" checker for .NET.',source:"@site/docs/checker-dotnet-resource-leak.md",sourceDirName:".",slug:"/checker-dotnet-resource-leak",permalink:"/docs/next/checker-dotnet-resource-leak",tags:[],version:"current",frontMatter:{title:"Resource Leak checker for .NET",description:'"resource leak" checker for .NET.'},sidebar:"docs",previous:{title:"Resource Leak Lab Exercise",permalink:"/docs/next/checker-resource-leak-lab"},next:{title:"Scope Leakage",permalink:"/docs/next/checker-scope-leakage"}},s=[{value:"List of Issue Types",id:"list-of-issue-types",children:[],level:2}],p={toc:s};function f(e){var r=e.components,t=(0,o.Z)(e,a);return(0,c.kt)("wrapper",(0,n.Z)({},p,t,{components:r,mdxType:"MDXLayout"}),(0,c.kt)("p",null,'"resource leak" checker for .NET.'),(0,c.kt)("p",null,"Activate with ",(0,c.kt)("inlineCode",{parentName:"p"},"--dotnet-resource-leak"),"."),(0,c.kt)("p",null,"Supported languages:"),(0,c.kt)("ul",null,(0,c.kt)("li",{parentName:"ul"},"C/C++/ObjC: No"),(0,c.kt)("li",{parentName:"ul"},"C#/.Net: Yes"),(0,c.kt)("li",{parentName:"ul"},"Erlang: No"),(0,c.kt)("li",{parentName:"ul"},"Hack: No"),(0,c.kt)("li",{parentName:"ul"},"Java: No")),(0,c.kt)("h2",{id:"list-of-issue-types"},"List of Issue Types"),(0,c.kt)("p",null,"The following issue types are reported by this checker:"),(0,c.kt)("ul",null,(0,c.kt)("li",{parentName:"ul"},(0,c.kt)("a",{parentName:"li",href:"/docs/next/all-issue-types#dotnet_resource_leak"},"DOTNET_RESOURCE_LEAK"))))}f.isMDXComponent=!0}}]);