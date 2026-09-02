# URL Prefix Replacer

一个纯前端的 URL 前缀替换工具：把 URL 里的源域名前缀换成目标域名前缀，路径与查询参数原样保留。

## 现在的规则（写死在页面里）

- 源前缀：`https://www.skyvendorise.com`
- 目标前缀：`https://label.alibaba-inc.com`
- 域名匹配不区分大小写
- 拼接时自动规范化斜杠，避免出现 `//`

## 使用

打开首页，把原 URL 粘到输入框，页面会实时显示替换后的 URL，点 **打开替换后的 URL** 即可跳转。

如果浏览器拦截了新窗口，页面会自动把结果复制到剪贴板并提示你手动粘贴，或者点 **复制结果** 按钮直接复制。

### 示例

```
输入：https://www.skyvendorise.com/corpora/labeling/sdk?subTaskId=68233815&missionType=sample&taskId=51972&projectId=5508
输出：https://label.alibaba-inc.com/corpora/labeling/sdk?subTaskId=68233815&missionType=sample&taskId=51972&projectId=5508
```

### 边界

- 输入为空：按钮 disabled
- 输入不以源前缀开头：显示"未匹配到规则，已原样保留"，按钮仍可点（打开原 URL），由你自己判断
- 输入正好等于源前缀（无路径）：输出目标前缀本身
- 大小写混用（`HTTPS://WWW.SKYVENDORISE.COM/...`）：也能识别，输出保留你输入的大小写形态

## 修改规则

规则写在 `index.html` 顶部的 `<script>` 里：

```js
var SOURCE = 'https://www.skyvendorise.com';
var TARGET = 'https://label.alibaba-inc.com';
```

改成你自己的两个前缀就行。以后要变成"多规则可切换"也很容易扩展。

## 本地开发

无构建步骤，直接双击 `index.html` 就能用。

## 部署（GitHub Pages）

本仓库已启用 GitHub Pages，公开地址形如：

```
https://<你的 GitHub 用户名>.github.io/<仓库名>/
```

推送更新：

```bash
git add .
git commit -m "update"
git push
```

## License

MIT
