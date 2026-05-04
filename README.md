# MATERIAL

通过 [Git LFS](https://git-lfs.com/) 托管两个大文件：

| 文件 | 实际大小 | 入库形式 |
| --- | --- | --- |
| `SCOUT_papers_final_expanded.zip` | ~258 MB | 直接 LFS 跟踪 |
| `2023.03.27 70mm 1500 0.5 1.ravi` | ~10.24 GB | 切成 6 个 `*.partNN`（每片 ≤ 1.8 GB，绕开 GitHub LFS 单文件 2 GB 上限） |

## 仓库内容

```
.
├── 2023.03.27 70mm 1500 0.5 1.ravi.part01..06   # LFS：原 .ravi 的 6 个分片
├── SCOUT_papers_final_expanded.zip              # LFS：论文压缩包
├── merge-ravi.ps1                               # 合并 .ravi 分片
├── split-ravi.ps1                               # 重新切分原 .ravi（仅维护者用）
├── Pull-And-Merge.ps1                           # 一键 clone + lfs pull + 合并
├── Push-Repo.ps1                                # 一键带 token 推送（仅维护者用）
├── .gitattributes                               # LFS 跟踪规则
└── .gitignore                                   # 忽略合并后的原 .ravi
```

---

## 一、下载 / 合并教程（使用方）

### 前置依赖

- [Git](https://git-scm.com/)
- [Git LFS](https://git-lfs.com/)（安装后执行一次 `git lfs install`）
- Windows PowerShell 5+（脚本路径）；或者 Linux/macOS 用手动方式
- 磁盘空间：仓库本身约 10.5 GB，合并后再 +10 GB（合并完可删分片）

### 方式 A：一键脚本（Windows，推荐）

在任意空目录里：

```powershell
# 先把脚本本体拉下来
Invoke-WebRequest `
  https://raw.githubusercontent.com/dongwinterdong/MATERIAL/main/Pull-And-Merge.ps1 `
  -OutFile .\Pull-And-Merge.ps1

# 一键执行
powershell -NoProfile -ExecutionPolicy Bypass -File .\Pull-And-Merge.ps1
```

脚本会依次跑：

1. `git lfs install` — 启用 LFS hooks
2. `git clone --progress` — 克隆仓库（**带进度**，仅拉指针 <10 MB）
3. `git lfs pull` — 下载 LFS 对象（**带进度**，约 10 GB）
4. 调用 `merge-ravi.ps1` 把 6 个分片拼回原 `2023.03.27 70mm 1500 0.5 1.ravi`

如果你已经 clone 过了，进到仓库目录里加 `-SkipClone`：

```powershell
cd MATERIAL
..\Pull-And-Merge.ps1 -SkipClone
```

### 方式 B：手动分步

```bash
git lfs install                                    # 每台机器一次性

git clone https://github.com/dongwinterdong/MATERIAL.git
cd MATERIAL
git lfs pull                                       # 实际下载分片，自带进度条
```

合并 `.ravi` 分片，三选一：

**Windows PowerShell**

```powershell
.\merge-ravi.ps1
```

**Windows cmd（一行命令）**

```bat
copy /b "2023.03.27 70mm 1500 0.5 1.ravi.part01" + "2023.03.27 70mm 1500 0.5 1.ravi.part02" + "2023.03.27 70mm 1500 0.5 1.ravi.part03" + "2023.03.27 70mm 1500 0.5 1.ravi.part04" + "2023.03.27 70mm 1500 0.5 1.ravi.part05" + "2023.03.27 70mm 1500 0.5 1.ravi.part06" "2023.03.27 70mm 1500 0.5 1.ravi"
```

**Linux / macOS / Git Bash**

```bash
cat "2023.03.27 70mm 1500 0.5 1.ravi.part"?? > "2023.03.27 70mm 1500 0.5 1.ravi"
```

合完后你会得到 `2023.03.27 70mm 1500 0.5 1.ravi`（约 10.24 GB）。它已被 `.gitignore` 排除，**不会被误提交**。

### 校验完整性（推荐）

合并后用 SHA-256 算一次哈希，与维护者发布的值比对。

```powershell
# Windows PowerShell
Get-FileHash -Algorithm SHA256 '2023.03.27 70mm 1500 0.5 1.ravi'
```

```bash
# Linux / macOS
sha256sum '2023.03.27 70mm 1500 0.5 1.ravi'
```

---

## 二、上传 / 维护教程（维护方）

> **前提**：你的 GitHub 账户有足够的 LFS 配额。免费额度只有 1 GB 存储 + 1 GB/月带宽，本仓库约 10.5 GB，超出后服务器会拒绝。需要在 GitHub Billing 购买 LFS 数据包（$5 = 50 GB 存储 + 50 GB 带宽）。

### 一键上传命令

准备一个有 `repo` 写权限的 [Personal Access Token (classic)](https://github.com/settings/tokens) 或 fine-grained token：

```powershell
# 方式 1：参数传入
.\Push-Repo.ps1 -Token ghp_xxxxxxxxxxxxxxxxxxxx

# 方式 2：环境变量
$env:GITHUB_TOKEN = 'ghp_xxxxxxxxxxxxxxxxxxxx'
.\Push-Repo.ps1
```

脚本会：

1. 列出本仓库所有 LFS 对象 + 总大小，并在 >1 GB 时给出配额警告
2. 临时把 token 注入 `origin` URL 用作身份验证
3. `git lfs push --all origin main` — 上传 LFS 对象（**带进度条**）
4. `git push -u origin main --progress` — 推送 git 提交历史（**带进度**）
5. 在 `finally` 里**无论成功/失败/Ctrl-C** 都还原 `origin` URL，token 不会留在 `.git/config`

### 添加/替换大文件并重新切片

替换原 `.ravi` 后，重新切片：

```powershell
# 默认每片 1800 MB
.\split-ravi.ps1

# 自定义片大小（务必 < 2 GB，留些余量）
.\split-ravi.ps1 -ChunkSize 1500MB
```

然后正常 `git add` / `git commit` / `.\Push-Repo.ps1`。

### 安全提示

- Token 一旦在网络上传过就视为泄露风险，请尽量用一次性、最小权限（仅 `public_repo` 或单仓写权限）的 fine-grained PAT。
- 推送完成后建议在 GitHub Settings → Developer settings 里 Revoke 掉本次使用的 token。
- 所有脚本不会把 token 写入任何被提交的文件。

---

## 三、常见问题

**Q：clone 后这些 `*.partNN` 文件大小只有 1KB 几行文本？**
A：那是 LFS 指针文件。运行 `git lfs pull` 才会把真实内容下载下来。

**Q：`git lfs pull` 报 `LFS bandwidth quota exceeded`？**
A：维护者账户的 LFS 月带宽用完了，需要购买数据包或等下个月。

**Q：合并完原 `.ravi`，能不能删除分片？**
A：可以删工作区的分片节省磁盘，但**不要 `git rm`**（否则会破坏仓库内容）。下次需要时再 `git lfs pull` 即可。

**Q：能不能不切片，直接用 LFS 推一个 10 GB 文件？**
A：不能。GitHub LFS 单文件硬限制 2 GB（即使付费账户也是这个限制），所以必须切片。
