suppressPackageStartupMessages({
  library(data.table)
  library(sf)
  library(ggplot2)
  library(ggdendro)
})

if (interactive()) {
  .args <- c(
    "data/geo/tl_2019_us_county/tl_2019_us_county.shp",
    "output/depr/departure-diffusion_exp/simulated_depr_date_2019_01_01_d_2.csv",
    "output/figs/counties_cluster_dendro.png",
    "output/figs/counties_cluster_map.png",
    "output/figs/counties_cluster_map.png",
    "output/space_time_scale/spatial_cluster_geoids.csv",
    "output/space_time_scale/spatial_cluster_mean_area.csv"
  )
} else {
  .args <- commandArgs(trailingOnly = T)
}

.outputs <- tail(.args, 5)

counties <- st_read(.args[1])

depr <- fread(.args[2])

counties <- subset(counties, GEOID %in% unique(depr$geoid))
counties <- st_simplify(counties, dTolerance = 100, preserveTopology = T)

counties_cent <- st_centroid(counties)

distance_matrix <- as.matrix(st_distance(counties_cent))

hc <- hclust(as.dist(distance_matrix), method = "ward.D2")
ks <- as.integer(seq(from=5, to=length(counties_cent$GEOID)/2, by=10))

merge_heights <- sort(hc$height, decreasing = TRUE)
cut_heights <- merge_heights[ks-1]

dendro_df <- dendro_data(hc)

p_dendro <- ggdendrogram(dendro_df) + 
  geom_hline(yintercept = cut_heights, 
             color = "red", 
             size=0.2) + 
  scale_y_continuous(trans="log2",
                     breaks=cut_heights,
                     labels = ks) + 
  theme(axis.text.x = element_blank(),
        axis.text.y = element_text(color="red",
                                   angle=0)) + 
  labs(y = "Number of clusters",
       x = "Counties")

ggsave(.outputs[1],
       p_dendro,
       width=10,
       height=8, 
       units="in") 

regions <- list()
for (i in 1:length(ks)){
  groups <- cutree(hc, k = ks[i])
  counties$cluster <- groups
  counties$k <- ks[i]
  regions[[i]] <- counties
}

cluster_regions <- do.call(rbind, regions)

combined_regions <- cluster_regions %>% 
  dplyr::group_by(cluster, k) %>% 
  dplyr::summarise(geometry = st_union(geometry)) %>%
  st_cast("MULTIPOLYGON")

combined_regions$label <- paste("k =", combined_regions$k)

counties$k <- NA
counties$cluster <- NA
original_label <- paste0("Original (k = ", length(counties$COUNTYFP), ")")
counties$label <- original_label

combined_regions <- rbind(combined_regions,
      counties[, c("cluster", "k", "geometry", "label")])

combined_regions$label <- factor(combined_regions$label,
                                 levels = c(original_label, paste("k =", rev(sort(unique(combined_regions$k))))))

p_cluster_map <- ggplot(combined_regions) + 
  geom_sf(aes(fill=as.character(cluster)), 
          size=0) + 
  facet_wrap(~label) + 
  theme_void() + 
  theme(legend.position="none",
        strip.text = element_text(face="bold"))

ggsave(.outputs[2],
       p_cluster_map,
       width=10,
       height=8, 
       units="in") 

# Average size of counties with different 
area_size <- cluster_regions %>% 
  dplyr::group_by(k, cluster) %>% 
  dplyr::summarise(total_area = as.numeric(units::set_units(sum(st_area(geometry)), "km^2")),
                   total_counties = length(unique(GEOID))) %>% 
  st_drop_geometry() %>% 
  dplyr::group_by(k) %>% 
  dplyr::summarise(mean_area = mean(total_area),
                   mean_counties = mean(total_counties)) %>% 
  tidyr::pivot_longer(!k) %>% 
  dplyr::mutate(name = factor(name, levels=c("mean_area", "mean_counties"),
                              labels=c("Mean Area (Km2)", "Mean Number of Counties")))
  
p_area <- ggplot(area_size) + 
  geom_path(aes(x = k, y = value)) +
  geom_point(aes(x = k, y = value)) + 
  facet_wrap(~name, scales="free_y") + 
  scale_x_continuous(breaks=ks) + 
  labs(y="Value",
       x="Number of clusters") + 
  theme_classic() + 
  theme(strip.background = element_blank(),
        strip.text = element_text(face="bold"))

ggsave(.outputs[3],
       p_area,
       width=10,
       height=5, 
       units="in") 

# Output lookup relating GEOID to cluster
cluster_regions$k_cluster <- paste(cluster_regions$k, cluster_regions$cluster, sep="_")

fwrite(st_drop_geometry(cluster_regions[, c("GEOID", "k", "cluster", "k_cluster")]),
       .outputs[4])

mean_area <- data.table(subset(area_size, name == "Mean Area (Km2)"))
mean_area[, name := NULL]
mean_area[, mean_area := value]
mean_area[, value := NULL]

fwrite(mean_area, .outputs[5])

