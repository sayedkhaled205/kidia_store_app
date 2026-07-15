const String mockHomeLayoutJson = '''
{
  "version": 1,
  "page": "home",
  "locale": "ar",
  "updated_at": "2026-07-14T10:00:00Z",
  "blocks": [
    {
      "id": "home_hero_slider",
      "type": "hero_slider",
      "enabled": true,
      "data": {
        "aspect_ratio": 1.75,
        "auto_play": true,
        "interval_ms": 4500,
        "items": [
          {
            "id": "hero_back_to_school",
            "image_url": "https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?auto=format&fit=crop&w=1400&q=85",
            "title": "كل ما يحتاجه طفلك",
            "subtitle": "اختيارات مميزة للأطفال في مكان واحد",
            "action": {
              "type": "category",
              "value": "12"
            }
          },
          {
            "id": "hero_new_collection",
            "image_url": "https://images.unsplash.com/photo-1514090458221-65bb69cf63e6?auto=format&fit=crop&w=1400&q=85",
            "title": "وصلت تشكيلات جديدة",
            "subtitle": "اكتشف أحدث المنتجات المختارة بعناية",
            "action": {
              "type": "collection",
              "value": "new-arrivals"
            }
          }
        ]
      }
    },
    {
      "id": "categories_header",
      "type": "section_header",
      "enabled": true,
      "data": {
        "title": "تسوق حسب القسم",
        "subtitle": "اختر القسم المناسب لطفلك"
      }
    },
    {
      "id": "main_categories",
      "type": "category_grid",
      "enabled": true,
      "data": {
        "columns": 4,
        "show_names": true,
        "items": [
          {
            "id": 12,
            "name": "ملابس",
            "image_url": "https://images.unsplash.com/photo-1519238263530-99bdd11df2ea?auto=format&fit=crop&w=500&q=80",
            "action": {
              "type": "category",
              "value": "12"
            }
          },
          {
            "id": 18,
            "name": "ألعاب",
            "image_url": "https://images.unsplash.com/photo-1594787318286-3d835c1d207f?auto=format&fit=crop&w=500&q=80",
            "action": {
              "type": "category",
              "value": "18"
            }
          },
          {
            "id": 23,
            "name": "أحذية",
            "image_url": "https://images.unsplash.com/photo-1514989940723-e8e51635b782?auto=format&fit=crop&w=500&q=80",
            "action": {
              "type": "category",
              "value": "23"
            }
          },
          {
            "id": 31,
            "name": "مستلزمات",
            "image_url": "https://images.unsplash.com/photo-1602030028438-4cf153cbae9e?auto=format&fit=crop&w=500&q=80",
            "action": {
              "type": "category",
              "value": "31"
            }
          }
        ]
      }
    },
    {
      "id": "featured_banner",
      "type": "image_banner",
      "enabled": true,
      "data": {
        "image_url": "https://images.unsplash.com/photo-1522771930-78848d9293e8?auto=format&fit=crop&w=1400&q=85",
        "aspect_ratio": 2.45,
        "border_radius": 20,
        "semantic_label": "مجموعة مختارة للأطفال",
        "action": {
          "type": "collection",
          "value": "featured"
        }
      }
    },
    {
      "id": "featured_products",
      "type": "product_carousel",
      "enabled": true,
      "data": {
        "title": "منتجات مميزة",
        "show_view_all": true,
        "view_all_action": {
          "type": "collection",
          "value": "featured"
        },
        "items": [
          {
            "id": 1041,
            "name": "حقيبة أطفال يومية",
            "image_url": "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=700&q=85",
            "price": "749",
            "regular_price": "899",
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": "عرض",
            "action": {
              "type": "product",
              "value": "1041"
            }
          },
          {
            "id": 1042,
            "name": "حذاء رياضي للأطفال",
            "image_url": "https://images.unsplash.com/photo-1514989940723-e8e51635b782?auto=format&fit=crop&w=700&q=85",
            "price": "1199",
            "regular_price": null,
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": "جديد",
            "action": {
              "type": "product",
              "value": "1042"
            }
          },
          {
            "id": 1043,
            "name": "لعبة تعليمية خشبية",
            "image_url": "https://images.unsplash.com/photo-1598880940080-ff9a29891b85?auto=format&fit=crop&w=700&q=85",
            "price": "525",
            "regular_price": "650",
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": null,
            "action": {
              "type": "product",
              "value": "1043"
            }
          }
        ]
      }
    },
    {
      "id": "brands_header",
      "type": "section_header",
      "enabled": true,
      "data": {
        "title": "علامات نحبها",
        "subtitle": "تسوق من العلامات المتوفرة لدينا",
        "action_label": "عرض الكل",
        "action": {
          "type": "brands",
          "value": "all"
        }
      }
    },
    {
      "id": "featured_brands",
      "type": "brand_carousel",
      "enabled": true,
      "data": {
        "item_width": 100,
        "items": [
          {
            "id": 201,
            "name": "Woo Store",
            "logo_url": "https://placehold.co/300x180/F6F1FF/5D3FD3.png?text=Woo+Store",
            "action": {
              "type": "brand",
              "value": "201"
            }
          },
          {
            "id": 202,
            "name": "Little Steps",
            "logo_url": "https://placehold.co/300x180/FFF2E6/E67817.png?text=Little+Steps",
            "action": {
              "type": "brand",
              "value": "202"
            }
          },
          {
            "id": 203,
            "name": "Happy Kids",
            "logo_url": "https://placehold.co/300x180/EAF8F1/178A55.png?text=Happy+Kids",
            "action": {
              "type": "brand",
              "value": "203"
            }
          }
        ]
      }
    },
    {
      "id": "home_spacer",
      "type": "spacer",
      "enabled": true,
      "data": {
        "height": 12
      }
    },
    {
      "id": "latest_products",
      "type": "product_grid",
      "enabled": true,
      "data": {
        "title": "وصل حديثًا",
        "columns": 2,
        "show_view_all": true,
        "view_all_action": {
          "type": "collection",
          "value": "new-arrivals"
        },
        "items": [
          {
            "id": 1101,
            "name": "طقم أطفال قطني",
            "image_url": "https://images.unsplash.com/photo-1522771930-78848d9293e8?auto=format&fit=crop&w=700&q=85",
            "price": "890",
            "regular_price": null,
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": "جديد",
            "action": {
              "type": "product",
              "value": "1101"
            }
          },
          {
            "id": 1102,
            "name": "دمية قماش ناعمة",
            "image_url": "https://images.unsplash.com/photo-1559454403-b8fb88521f11?auto=format&fit=crop&w=700&q=85",
            "price": "340",
            "regular_price": "390",
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": null,
            "action": {
              "type": "product",
              "value": "1102"
            }
          },
          {
            "id": 1103,
            "name": "صندوق ألعاب تعليمي",
            "image_url": "https://images.unsplash.com/photo-1598880940080-ff9a29891b85?auto=format&fit=crop&w=700&q=85",
            "price": "675",
            "regular_price": null,
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": true,
            "badge": null,
            "action": {
              "type": "product",
              "value": "1103"
            }
          },
          {
            "id": 1104,
            "name": "حذاء أطفال خفيف",
            "image_url": "https://images.unsplash.com/photo-1514989940723-e8e51635b782?auto=format&fit=crop&w=700&q=85",
            "price": "990",
            "regular_price": "1150",
            "currency_code": "EGP",
            "currency_symbol": "ج.م",
            "in_stock": false,
            "badge": "نفد المخزون",
            "action": {
              "type": "product",
              "value": "1104"
            }
          }
        ]
      }
    }
  ]
}
''';
