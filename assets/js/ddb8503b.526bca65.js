"use strict";(self.webpackChunk=self.webpackChunk||[]).push([[6499],{3905:function(e,n,r){r.d(n,{Zo:function(){return l},kt:function(){return m}});var t=r(7294);function o(e,n,r){return n in e?Object.defineProperty(e,n,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[n]=r,e}function i(e,n){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var t=Object.getOwnPropertySymbols(e);n&&(t=t.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),r.push.apply(r,t)}return r}function a(e){for(var n=1;n<arguments.length;n++){var r=null!=arguments[n]?arguments[n]:{};n%2?i(Object(r),!0).forEach((function(n){o(e,n,r[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):i(Object(r)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(r,n))}))}return e}function c(e,n){if(null==e)return{};var r,t,o=function(e,n){if(null==e)return{};var r,t,o={},i=Object.keys(e);for(t=0;t<i.length;t++)r=i[t],n.indexOf(r)>=0||(o[r]=e[r]);return o}(e,n);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(t=0;t<i.length;t++)r=i[t],n.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(o[r]=e[r])}return o}var u=t.createContext({}),f=function(e){var n=t.useContext(u),r=n;return e&&(r="function"==typeof e?e(n):a(a({},n),e)),r},l=function(e){var n=f(e.components);return t.createElement(u.Provider,{value:n},e.children)},p={inlineCode:"code",wrapper:function(e){var n=e.children;return t.createElement(t.Fragment,{},n)}},s=t.forwardRef((function(e,n){var r=e.components,o=e.mdxType,i=e.originalType,u=e.parentName,l=c(e,["components","mdxType","originalType","parentName"]),s=f(r),m=o,d=s["".concat(u,".").concat(m)]||s[m]||p[m]||i;return r?t.createElement(d,a(a({ref:n},l),{},{components:r})):t.createElement(d,a({ref:n},l))}));function m(e,n){var r=arguments,o=n&&n.mdxType;if("string"==typeof e||o){var i=r.length,a=new Array(i);a[0]=s;var c={};for(var u in n)hasOwnProperty.call(n,u)&&(c[u]=n[u]);c.originalType=e,c.mdxType="string"==typeof e?e:o,a[1]=c;for(var f=2;f<i;f++)a[f]=r[f];return t.createElement.apply(null,a)}return t.createElement.apply(null,r)}s.displayName="MDXCreateElement"},2460:function(e,n,r){r.d(n,{Z:function(){return o}});var t=r(7294);function o(e){var n=e.url,r=(0,t.useState)({__html:""}),o=r[0],i=r[1];return(0,t.useEffect)((function(){fetch(n).then((function(e){return e.text()})).then((function(e){return i({__html:e})}))}),[n]),t.createElement("div",{dangerouslySetInnerHTML:o})}},8870:function(e,n,r){r.r(n),r.d(n,{contentTitle:function(){return f},default:function(){return m},frontMatter:function(){return u},metadata:function(){return l},toc:function(){return p}});var t=r(7462),o=r(3366),i=(r(7294),r(3905)),a=r(2460),c=["components"],u={id:"man-infer",title:"infer"},f=void 0,l={unversionedId:"man-infer",id:"version-1.0.0/man-infer",title:"infer",description:"",source:"@site/versioned_docs/version-1.0.0/man-infer.md",sourceDirName:".",slug:"/man-infer",permalink:"/docs/1.0.0/man-infer",tags:[],version:"1.0.0",frontMatter:{id:"man-infer",title:"infer"},sidebar:"version-1.0.0/docs",previous:{title:"Advanced usage",permalink:"/docs/1.0.0/advanced-features"},next:{title:"infer analyze",permalink:"/docs/1.0.0/man-infer-analyze"}},p=[],s={toc:p};function m(e){var n=e.components,r=(0,o.Z)(e,c);return(0,i.kt)("wrapper",(0,t.Z)({},s,r,{components:n,mdxType:"MDXLayout"}),(0,i.kt)(a.Z,{url:"/man/1.0.0/infer.1.html",mdxType:"HtmlWrap"}))}m.isMDXComponent=!0}}]);