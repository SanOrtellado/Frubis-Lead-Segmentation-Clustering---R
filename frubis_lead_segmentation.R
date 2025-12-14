# ============================
# Frubis - Lead Segmentation (Clustering)
# Servicios: Media Planning, Media Activation, Ad Ops, DD Dynamic Creative, CRO, Email/SMS, Landing/Funnel
# ============================

library(tidyverse)
library(cluster)
library(factoextra)
library(scales)

set.seed(42)

# 1) Generar dataset sintético (leads B2B)
n <- 900

# Tipos latentes (simulan “intenciones” distintas)
latent <- sample(c("Performance_Ready","CRO_Focus","CRM_Nurture","Explorers"), size = n,
                 replace = TRUE, prob = c(0.35, 0.20, 0.25, 0.20))

gen_lead <- function(t){
  # base
  company_size <- round(rlnorm(1, meanlog = 3.6, sdlog = 0.6)) # empleados aprox
  monthly_budget_usd <- round(rlnorm(1, meanlog = 8.2, sdlog = 0.55)) # presupuesto estimado (proxy)
  sessions_30d <- round(rlnorm(1, meanlog = 2.4, sdlog = 0.55))
  
  # señales de intención por servicio (views/clicks normalizados)
  # (en la vida real: pageviews por URL/scroll depth/cta clicks)
  base_intent <- runif(1, 0.05, 0.25)
  
  media_planning <- base_intent
  media_activation <- base_intent
  ad_ops <- base_intent
  dd_creative <- base_intent
  cro <- base_intent
  email_sms <- base_intent
  landing_funnel <- base_intent
  
  # ajustar por tipo
  if (t == "Performance_Ready") {
    media_activation <- runif(1, 0.35, 0.75)
    media_planning  <- runif(1, 0.25, 0.60)
    ad_ops          <- runif(1, 0.20, 0.55)
    dd_creative     <- runif(1, 0.20, 0.55)
    cro             <- runif(1, 0.10, 0.35)
    email_sms       <- runif(1, 0.05, 0.25)
    landing_funnel  <- runif(1, 0.10, 0.35)
  } else if (t == "CRO_Focus") {
    cro            <- runif(1, 0.40, 0.85)
    landing_funnel <- runif(1, 0.30, 0.80)
    dd_creative    <- runif(1, 0.15, 0.45)
    media_activation <- runif(1, 0.10, 0.35)
    media_planning <- runif(1, 0.10, 0.30)
    ad_ops         <- runif(1, 0.05, 0.25)
    email_sms      <- runif(1, 0.10, 0.35)
  } else if (t == "CRM_Nurture") {
    email_sms      <- runif(1, 0.40, 0.85)
    dd_creative    <- runif(1, 0.20, 0.55)
    cro            <- runif(1, 0.15, 0.45)
    landing_funnel <- runif(1, 0.10, 0.35)
    media_activation <- runif(1, 0.05, 0.25)
    media_planning <- runif(1, 0.05, 0.20)
    ad_ops         <- runif(1, 0.05, 0.20)
  } else if (t == "Explorers") {
    media_planning <- runif(1, 0.15, 0.45)
    landing_funnel <- runif(1, 0.15, 0.45)
    cro            <- runif(1, 0.10, 0.35)
    email_sms      <- runif(1, 0.10, 0.35)
    media_activation <- runif(1, 0.10, 0.35)
    ad_ops         <- runif(1, 0.05, 0.25)
    dd_creative    <- runif(1, 0.10, 0.35)
  }
  
  # acciones (proxy de intención)
  cta_book_call <- rbinom(1, 1, prob = pmin(0.85, 0.10 + 0.60*media_activation + 0.35*cro))
  cta_contact   <- rbinom(1, 1, prob = pmin(0.80, 0.08 + 0.45*email_sms + 0.40*landing_funnel))
  
  tibble(
    company_size = company_size,
    monthly_budget_usd = monthly_budget_usd,
    sessions_30d = sessions_30d,
    intent_media_planning = media_planning,
    intent_media_activation = media_activation,
    intent_ad_ops = ad_ops,
    intent_dd_creative = dd_creative,
    intent_cro = cro,
    intent_email_sms = email_sms,
    intent_landing_funnel = landing_funnel,
    cta_book_call = cta_book_call,
    cta_contact = cta_contact
  )
}

df <- map_dfr(latent, gen_lead) %>%
  mutate(
    lead_id = sprintf("L%04d", 1:n),
    # features transform
    log_budget = log1p(monthly_budget_usd),
    log_company = log1p(company_size),
    log_sessions = log1p(sessions_30d),
    intent_total = intent_media_planning + intent_media_activation + intent_ad_ops +
      intent_dd_creative + intent_cro + intent_email_sms + intent_landing_funnel,
    readiness = 0.55*cta_book_call + 0.45*cta_contact
  ) %>%
  select(lead_id, log_budget, log_company, log_sessions,
         starts_with("intent_"), readiness)

# 2) Escalado
X <- df %>% select(-lead_id) %>% scale()

# 3) Elegir K (rápido: WSS + silhouette)
p1 <- fviz_nbclust(X, kmeans, method = "wss") + ggtitle("Elbow (WSS)")
p2 <- fviz_nbclust(X, kmeans, method = "silhouette") + ggtitle("Silhouette")
print(p1); print(p2)

# 4) KMeans
k <- 4
km <- kmeans(X, centers = k, nstart = 30)

out <- df %>% mutate(cluster = factor(km$cluster))

# 5) Perfilado de clusters
profile <- out %>%
  group_by(cluster) %>%
  summarise(
    n = n(),
    budget_avg_usd = round(mean(expm1(log_budget))),
    company_size_proxy = round(mean(expm1(log_company))),
    sessions_avg = round(mean(expm1(log_sessions))),
    planning = mean(intent_media_planning),
    activation = mean(intent_media_activation),
    adops = mean(intent_ad_ops),
    ddcreative = mean(intent_dd_creative),
    cro = mean(intent_cro),
    email = mean(intent_email_sms),
    landing = mean(intent_landing_funnel),
    readiness = mean(readiness),
    .groups = "drop"
  ) %>%
  mutate(share = percent(n/sum(n), accuracy = 0.1)) %>%
  arrange(desc(n))

print(profile)

# 6) Naming + “next best service”
segments <- profile %>%
  mutate(segment = case_when(
    activation > 0.45 & readiness > 0.55 ~ "Performance Ready (Activation/Ads)",
    cro > 0.55 & landing > 0.45 ~ "CRO & Funnel Builders",
    email > 0.55 ~ "CRM Nurture (Email/SMS)",
    TRUE ~ "Explorers (Planning + Mixed)"
  )) %>%
  mutate(next_best_service = case_when(
    segment == "Performance Ready (Activation/Ads)" ~ "Media Activation + Ad Operations + Dynamic Creative",
    segment == "CRO & Funnel Builders" ~ "CRO + Landing page & Sales Funnel Creation",
    segment == "CRM Nurture (Email/SMS)" ~ "Email & SMS + Dynamic Creative",
    TRUE ~ "Media Planning (diagnóstico) + roadmap de Growth"
  )) %>%
  select(cluster, segment, next_best_service)

final <- out %>%
  left_join(segments, by = "cluster")

# 7) Visualizaciones para LinkedIn
# PCA clusters
p_pca <- fviz_cluster(km, data = X, geom = "point", ellipse.type = "norm") +
  ggtitle("Frubis Lead Segmentation - KMeans (PCA view)")
print(p_pca)

# barras por segmento
p_seg <- final %>%
  count(segment, sort = TRUE) %>%
  ggplot(aes(x = reorder(segment, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(title = "Leads por segmento", x = NULL, y = "Cantidad")
print(p_seg)

# heatmap simple de interés por servicio (promedios)
heat <- profile %>%
  select(cluster, planning, activation, adops, ddcreative, cro, email, landing, readiness) %>%
  pivot_longer(-cluster, names_to = "feature", values_to = "value") %>%
  group_by(feature) %>% mutate(z = as.numeric(scale(value))) %>% ungroup()

p_heat <- ggplot(heat, aes(x = feature, y = cluster, fill = z)) +
  geom_tile() +
  labs(title = "Perfil de clusters (z-score)", x = NULL, y = NULL) +
  theme(axis.text.x = element_text(angle = 35, hjust = 1))
print(p_heat)

# 8) Exportables
write.csv(final, "frubis_leads_segmented.csv", row.names = FALSE)
ggsave("frubis_pca_clusters.png", p_pca, width = 8, height = 5, dpi = 160)
ggsave("frubis_leads_by_segment.png", p_seg, width = 8, height = 5, dpi = 160)
ggsave("frubis_cluster_heatmap.png", p_heat, width = 10, height = 4.8, dpi = 160)

message("OK: frubis_leads_segmented.csv + 3 PNGs generados.")

