# Implementation Plan: Smart Recommendation & Interaction System (v1)

Bu plan, Outfitter uygulamasının öneri motorunu güçlendirmek ve kullanıcı etkileşimlerini ML eğitim verisine dönüştürmek için gereken adımları kapsar.

> **ÖNEMLİ:** Tüm değişiklikler önce **Wardrobe** tarafında uygulanacak, test edilecek ve doğrulandıktan sonra Catalog tarafına taşınacaktır.

---

## 1. Mevcut Durum ve Eksiklerin Tespiti

| Alan | Mevcut Durum | Eksik / Sorun |
|---|---|---|
| **Veri Derinliği** | Sadece category, color, pattern, fit, style_tags var | `material`, `season`, `occasion`, `primary_style` eksik |
| **Etkileşim** | Sadece "Save to Lookbook" var | Swipe, like, dislike verisi tutulmuyor |
| **Öneriler** | Sadece CLIP görsel benzerliği | Kural + kişisel tercih tabanlı hibrit yapı yok |
| **Katalog** | 4714 ürün var | CLIP embedding'ler boş (0/4714) |
| **Wardrobe** | 3 ürün, 2 embedding var | Yeni meta veriler (season vb.) eksik |

---

## 2. Step-by-Step Implementation Plan

### STEP 1: Wardrobe Model — Yeni Metadata Kolonları ✅
**Dosya:** `app/models/wardrobe.py`
**Durum:** Tamamlandı
- [x] `season` (ARRAY) eklendi
- [x] `material` (ARRAY) eklendi
- [x] `occasion` (ARRAY) eklendi
- [x] `primary_style` (String) eklendi

### STEP 2: Wardrobe Pydantic Şemaları ✅
**Dosya:** `app/schemas/wardrobe.py`
**Durum:** Tamamlandı
- [x] `WardrobeItemCreate` güncellendi
- [x] `WardrobeTagResponse` güncellendi
- [x] `WardrobeItemResponse` güncellendi

### STEP 3: Kullanıcı Etkileşim & Profil Modelleri ✅
**Dosya:** `app/models/user.py`
**Durum:** Tamamlandı
- [x] `UserInteraction` modeli eklendi (swipe_left, swipe_right, like, view, try_on)
- [x] `UserProfile` modeli eklendi (preferred_styles, disliked_colors, body_type)

### STEP 4: Gemini Tagging Prompt Güncelleme ⬜
**Dosya:** `app/services/gemini_service.py`
**Durum:** Sırada
- [ ] `TAGGING_PROMPT`'a `season`, `material`, `occasion`, `primary_style` alanları eklenmeli
- [ ] Mevcut alanlar korunmalı, sadece yeni alanlar eklenmeli
- [ ] Gemini'nin döndüğü JSON'da bu alanlar olmalı

### STEP 5: Wardrobe Router Güncelleme ⬜
**Dosya:** `app/routers/wardrobe.py`
**Durum:** Bekliyor (Step 4'ten sonra)
- [ ] `POST /wardrobe` (create) endpoint'inde yeni alanları DB'ye kaydetme
- [ ] Mevcut `POST /wardrobe/tag` endpoint'inin yeni tag formatıyla uyumu test edilmeli

### STEP 6: Interaction API Endpoint'leri ⬜
**Dosya:** `app/routers/interactions.py` (YENİ)
**Durum:** Bekliyor
- [ ] `POST /interactions` — swipe/like/view/try_on kaydetme
- [ ] `GET /interactions/history` — kullanıcının etkileşim geçmişi
- [ ] Router'ı `main.py`'a register etme

### STEP 7: Alembic Migration ⬜
**Durum:** Tüm model değişiklikleri tamamlandıktan sonra
- [ ] `wardrobe_items` tablosuna yeni kolonlar
- [ ] `user_interactions` tablosu oluşturma
- [ ] `user_profiles` tablosu oluşturma
- [ ] Migration'ı test ortamında deneme

### STEP 8: Catalog Tarafına Taşıma ⬜
**Durum:** Wardrobe tamamen test edildikten sonra
- [ ] `CatalogItem` modeline aynı kolonları ekleme
- [ ] Catalog schema'larını güncelleme
- [ ] Mevcut 4714 ürün için batch re-tagging script'i

---

## 3. Machine Learning Yol Haritası

### 3.1 ML Modeli Nedir ve Neden Lazım?

Kural tabanlı sistemler (mevsim filtresi, renk uyumu) iyi bir başlangıçtır ama her kullanıcı farklıdır. ML modeli, kullanıcının **kişisel zevkini** öğrenir:

- "Bu kullanıcı hep oversized kıyafetleri sağa kaydırıyor" → oversized öner
- "Bu kullanıcı hiç leopar desen beğenmedi" → leopar önerme
- "Bu kullanıcıya benzer insanlar şu kombini sevdi" → ona da öner

### 3.2 Veri Toplama (Şimdiden Başlamalı)

ML modeli eğitmek için **en az 1000-5000 etkileşim** verisi lazım. Bu yüzden `user_interactions` tablosunu **şimdiden** kuruyoruz — model eğitmeden önce veri biriktirmeye başlamalıyız.

Her etkileşim bir satır:
```
| user_id | target_id | target_type | action       | created_at |
|---------|-----------|-------------|--------------|------------|
| u1      | item_42   | wardrobe    | swipe_right  | 2026-05-01 |
| u1      | item_99   | catalog     | swipe_left   | 2026-05-01 |
| u1      | outfit_7  | outfit      | like         | 2026-05-01 |
```

### 3.3 Model Mimarisi: Two-Tower

```
  Kullanıcı Verisi              Ürün Verisi
  ┌─────────────┐              ┌─────────────┐
  │ Beğenilen   │              │ Kategori    │
  │ stiller     │              │ Renk        │
  │ Renk tercihi│              │ Materyal    │
  │ Son 20 swipe│              │ Mevsim      │
  │ Vücut tipi  │              │ CLIP vektörü│
  └──────┬──────┘              └──────┬──────┘
         │                            │
    ┌────▼────┐                  ┌────▼────┐
    │ User    │                  │ Item    │
    │ Encoder │                  │ Encoder │
    │ (MLP)   │                  │ (MLP)   │
    └────┬────┘                  └────┬────┘
         │                            │
    User Embedding              Item Embedding
    [128-dim vektör]            [128-dim vektör]
         │                            │
         └──────────┬─────────────────┘
                    │
              Dot Product
              (Benzerlik Skoru)
                    │
              ┌─────▼─────┐
              │ Score: 0.87│ → "Bu kullanıcı bunu beğenecek"
              │ Score: 0.23│ → "Bunu beğenmeyecek"
              └───────────┘
```

### 3.4 Model Eğitimi — Adım Adım

**Araçlar:** Python, PyTorch, scikit-learn

#### Adım 1: Veri Hazırlama
```python
# user_interactions tablosundan veri çek
# swipe_right / like → label = 1 (pozitif)
# swipe_left        → label = 0 (negatif)

import pandas as pd
from sqlalchemy import select
from app.models.user import UserInteraction

# DataFrame: [user_id, item_id, item_features..., label]
```

#### Adım 2: Feature Engineering
```python
# Her kullanıcı için:
# - En çok beğendiği 3 renk
# - En çok beğendiği 2 stil
# - Ortalama CLIP embedding'i (beğendiği ürünlerin ortalaması)
# - Beğenme/beğenmeme oranı

# Her ürün için:
# - category, material, season, occasion → one-hot encoding
# - CLIP embedding (512-dim) → direkt kullanılacak
# - primary_style → label encoding
```

#### Adım 3: Model Tanımlama (PyTorch)
```python
import torch
import torch.nn as nn

class UserTower(nn.Module):
    def __init__(self, user_feature_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(user_feature_dim, 256),
            nn.ReLU(),
            nn.Linear(256, 128),
            nn.LayerNorm(128),
        )

    def forward(self, user_features):
        return self.net(user_features)

class ItemTower(nn.Module):
    def __init__(self, item_feature_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(item_feature_dim, 256),
            nn.ReLU(),
            nn.Linear(256, 128),
            nn.LayerNorm(128),
        )

    def forward(self, item_features):
        return self.net(item_features)

class TwoTowerModel(nn.Module):
    def __init__(self, user_dim, item_dim):
        super().__init__()
        self.user_tower = UserTower(user_dim)
        self.item_tower = ItemTower(item_dim)

    def forward(self, user_features, item_features):
        user_emb = self.user_tower(user_features)
        item_emb = self.item_tower(item_features)
        # Dot product → benzerlik skoru
        score = (user_emb * item_emb).sum(dim=-1)
        return torch.sigmoid(score)
```

#### Adım 4: Eğitim Döngüsü
```python
model = TwoTowerModel(user_dim=64, item_dim=580)  # 580 = 512 CLIP + 68 metadata
optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
loss_fn = nn.BCELoss()

for epoch in range(50):
    for batch in dataloader:
        user_feats, item_feats, labels = batch
        predictions = model(user_feats, item_feats)
        loss = loss_fn(predictions, labels)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

    print(f"Epoch {epoch}: Loss = {loss.item():.4f}")

# Modeli kaydet
torch.save(model.state_dict(), "recommendation_model_v1.pt")
```

#### Adım 5: Modeli Backend'e Entegre Etme
```python
# app/services/recommendation_service.py

class RecommendationService:
    def __init__(self):
        self.model = TwoTowerModel(user_dim=64, item_dim=580)
        self.model.load_state_dict(torch.load("recommendation_model_v1.pt"))
        self.model.eval()

    async def get_recommendations(self, user_id, candidate_items, limit=20):
        user_features = await self._build_user_features(user_id)
        scores = []
        for item in candidate_items:
            item_features = self._build_item_features(item)
            score = self.model(user_features, item_features)
            scores.append((item, score.item()))

        # En yüksek skorlu ürünleri döndür
        scores.sort(key=lambda x: x[1], reverse=True)
        return scores[:limit]
```

### 3.5 ML Zaman Çizelgesi

| Aşama | Ne Zaman | Gereksinim |
|---|---|---|
| Veri toplama altyapısı | **ŞİMDİ** (Step 3, 6) | `user_interactions` tablosu |
| Kural tabanlı öneriler (V1) | 2-3 hafta sonra | Mevsim + renk uyumu filtreleri |
| İlk ML denemesi | 5000+ etkileşim biriktikten sonra | PyTorch + eğitim script'i |
| Üretim ML modeli | 20.000+ etkileşim sonrası | A/B test + model versiyonlama |

---

## 4. Dikkat Edilmesi Gerekenler

- **Geriye uyumluluk:** Yeni alanlar `nullable=True` olduğundan mevcut veriler bozulmaz
- **Gemini fallback:** Gemini yeni alanları döndürmezse, eski format da kabul edilmeli
- **Migration sırası:** Önce model, sonra migration, sonra router — bu sıra bozulmamalı
- **Catalog dokunulmayacak:** Wardrobe tamamen test edilene kadar catalog dosyalarına dokunulmayacak
