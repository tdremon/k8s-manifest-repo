# k8s-manifest-repo

[Argo CD](https://argo-cd.readthedocs.io/)가 읽는 **배포 전용 저장소**입니다. 앱 코드와 CI(이미지 빌드·GHCR push)는 별도 저장소에 있고, 이 저장소에는 "클러스터에 무엇이 떠 있어야 하는가"만 둡니다.

```
앱 repo 에 push → CI 가 이미지 빌드 → GHCR push → (CI 가 이 repo 의 image.tag 갱신) → Argo CD 가 변경 감지 → 클러스터에 sync
```

## 구조

| 경로 | 내용 |
|---|---|
| `charts/pytorch-infer/` | PyTorch 추론 서버(FastAPI) Helm chart. `values.yaml` 이 기본값이고 `values-kind.yaml` 에 kind 환경의 차이만 둔다 |
| `argocd/pytorch-infer-app.yaml` | Argo CD `Application`. 어느 경로를 어느 클러스터/네임스페이스에 어떤 정책으로 배포할지 선언한다 |

## 원칙

- **Secret 값은 이 저장소에 두지 않습니다.** chart 는 `imagePullSecrets` 로 Secret 의 이름(`ghcr-pull`)만 가리키고, Secret 은 클러스터에 직접 만듭니다.
- 이미지 태그는 `latest` 가 아니라 앱 커밋 SHA(`sha-xxxxxxx`)를 씁니다. 배포 이력은 이 저장소의 커밋으로 남고, 롤백은 `git revert` 로 합니다.
- 이 저장소는 학습용 kind 클러스터 기준입니다. 이전에 이 저장소에 있던 내용(Kustomize 기반 EKS 데모)은 Git 이력에서 볼 수 있습니다.
