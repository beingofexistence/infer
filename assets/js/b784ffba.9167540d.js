"use strict";(self.webpackChunk=self.webpackChunk||[]).push([[2913],{3905:function(e,n,r){r.d(n,{Zo:function(){return f},kt:function(){return m}});var t=r(7294);function o(e,n,r){return n in e?Object.defineProperty(e,n,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[n]=r,e}function i(e,n){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var t=Object.getOwnPropertySymbols(e);n&&(t=t.filter((function(n){return Object.getOwnPropertyDescriptor(e,n).enumerable}))),r.push.apply(r,t)}return r}function c(e){for(var n=1;n<arguments.length;n++){var r=null!=arguments[n]?arguments[n]:{};n%2?i(Object(r),!0).forEach((function(n){o(e,n,r[n])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):i(Object(r)).forEach((function(n){Object.defineProperty(e,n,Object.getOwnPropertyDescriptor(r,n))}))}return e}function a(e,n){if(null==e)return{};var r,t,o=function(e,n){if(null==e)return{};var r,t,o={},i=Object.keys(e);for(t=0;t<i.length;t++)r=i[t],n.indexOf(r)>=0||(o[r]=e[r]);return o}(e,n);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(t=0;t<i.length;t++)r=i[t],n.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(o[r]=e[r])}return o}var u=t.createContext({}),l=function(e){var n=t.useContext(u),r=n;return e&&(r="function"==typeof e?e(n):c(c({},n),e)),r},f=function(e){var n=l(e.components);return t.createElement(u.Provider,{value:n},e.children)},p={inlineCode:"code",wrapper:function(e){var n=e.children;return t.createElement(t.Fragment,{},n)}},s=t.forwardRef((function(e,n){var r=e.components,o=e.mdxType,i=e.originalType,u=e.parentName,f=a(e,["components","mdxType","originalType","parentName"]),s=l(r),m=o,d=s["".concat(u,".").concat(m)]||s[m]||p[m]||i;return r?t.createElement(d,c(c({ref:n},f),{},{components:r})):t.createElement(d,c({ref:n},f))}));function m(e,n){var r=arguments,o=n&&n.mdxType;if("string"==typeof e||o){var i=r.length,c=new Array(i);c[0]=s;var a={};for(var u in n)hasOwnProperty.call(n,u)&&(a[u]=n[u]);a.originalType=e,a.mdxType="string"==typeof e?e:o,c[1]=a;for(var l=2;l<i;l++)c[l]=r[l];return t.createElement.apply(null,c)}return t.createElement.apply(null,r)}s.displayName="MDXCreateElement"},2460:function(e,n,r){r.d(n,{Z:function(){return o}});var t=r(7294);function o(e){var n=e.url,r=(0,t.useState)({__html:""}),o=r[0],i=r[1];return(0,t.useEffect)((function(){fetch(n).then((function(e){return e.text()})).then((function(e){return i({__html:e})}))}),[n]),t.createElement("div",{dangerouslySetInnerHTML:o})}},8367:function(e,n,r){r.r(n),r.d(n,{contentTitle:function(){return l},default:function(){return m},frontMatter:function(){return u},metadata:function(){return f},toc:function(){return p}});var t=r(7462),o=r(3366),i=(r(7294),r(3905)),c=r(2460),a=["components"],u={id:"man-infer-help",title:"infer help"},l=void 0,f={unversionedId:"man-infer-help",id:"version-1.0.0/man-infer-help",title:"infer help",description:"",source:"@site/versioned_docs/version-1.0.0/man-infer-help.md",sourceDirName:".",slug:"/man-infer-help",permalink:"/docs/1.0.0/man-infer-help",tags:[],version:"1.0.0",frontMatter:{id:"man-infer-help",title:"infer help"},sidebar:"version-1.0.0/docs",previous:{title:"infer explore",permalink:"/docs/1.0.0/man-infer-explore"},next:{title:"infer report",permalink:"/docs/1.0.0/man-infer-report"}},p=[],s={toc:p};function m(e){var n=e.components,r=(0,o.Z)(e,a);return(0,i.kt)("wrapper",(0,t.Z)({},s,r,{components:n,mdxType:"MDXLayout"}),(0,i.kt)(c.Z,{url:"/man/1.0.0/infer-help.1.html",mdxType:"HtmlWrap"}))}m.isMDXComponent=!0}}]);