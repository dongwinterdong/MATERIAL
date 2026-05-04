# MATERIAL

本仓库通过 [Git LFS](https://git-lfs.com/) 托管两个大文件：

| 文件 | 实际大小 | 入库形式 |
| --- | --- | --- |
| `SCOUT_papers_final_expanded.zip` | ~258 MB | 直接由 LFS 跟踪 |
| `2023.03.27 70mm 1500 0.5 1.ravi` | ~10.24 GB | 切成 6 个 `*.partNN` 由 LFS 跟踪（GitHub LFS 单文件 2 GB 上限） |

## 拉取步骤

```bash
# 一次性安装 LFS（每台机器一次）
git lfs install

# 克隆
git clone https://github.com/dongwinterdong/MATERIAL.git
cd MATERIAL

# 如果克隆时只下了指针文件，再拉一次 LFS 内容
git lfs pull
```

## 合并 .ravi 分片

仓库根目录里有 `merge-ravi.ps1`，按字典序拼接所有 `2023.03.27 70mm 1500 0.5 1.ravi.partNN` 还原原文件：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\merge-ravi.ps1
```

合并完成后会得到 `2023.03.27 70mm 1500 0.5 1.ravi`（约 10.24 GB）。该文件已被 `.gitignore` 排除，不会被误提交。

## 重新切片（可选）

若需替换原文件并重新生成分片：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\split-ravi.ps1
```

默认每片 1800 MB；可用 `-ChunkSize` 调整，但务必 < 2 GB 以满足 GitHub LFS 限制。
