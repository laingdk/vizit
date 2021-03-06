#' Aggregates dataframe by video and segment
#' @description Aggregates input dataframe by video (video_id) and segment 
#'   (min_into_video).
#' Additionally, adds columns:
#'
#' - \code{unique_views}/\code{`Students`} (number of learners who started the 
#'   video),
#'
#' - \code{watch_rate}/\code{`Views per Student`} (number of students who have 
#'   watched the segment divided by unique_views),
#'
#' - \code{avg_watch_rate} (average of watch_rate per video)
#' 
#' - \code{high_low} ('High Watch Rate', 'Low Watch Rate, or 'Normal')
#' 
#' - \code{up_until} (1 if the average learner had watched up until the 
#'   particular min_into_video, 0 if they had not)
#'
#' @param filt_segs Dataframe containing students that have been filtered by 
#'   selected demographics. Typically obtained via \code{filter_demographics()}
#' @param top_selection Value of the number of top segments to highlight.
#' @param video_axis The table of video attributes.
#'
#' @return \code{aggregate_segment_df}: Aggregated dataframe with additional 
#'   columns
#' @export
#'
#' @examples
#' get_aggregated_df(filt_segs, 25, video_axis)
get_aggregated_df <- function(filt_segs, top_selection) {
  
  aggregate_segment_df <- filt_segs %>% 
    dplyr::filter(is.na(user_id) == FALSE) %>% 
    group_by(video_id, min_into_video, segment, last_segment) %>% 
    summarize(count = sum(count),
              course_order = unique(course_order), 
              vid_length = unique(max_stop_position), 
              video_name = unique(video_name)) %>% 
    ungroup() %>% 
    mutate(min_into_video = as.double(min_into_video))
    
  # Getting dataframe with number of unique user views of videos Note:
  # This still counts scenarios if a person watches a video for 0.125
  # seconds No thresholding has been conducted.
  unique_views <- filt_segs %>% 
    group_by(video_id) %>% 
    summarize(unique_views = n_distinct(user_id)) %>% 
    arrange(unique_views) %>%
    ungroup()
  
  # Place number of unique view column into dataframe:
  aggregate_segment_df <- aggregate_segment_df %>% 
    left_join(unique_views, by = "video_id") %>% 
    mutate(watch_rate = count/unique_views) %>% 
    mutate(`Views per Student` = round(watch_rate, 2)) %>% 
    mutate(Students = unique_views) %>% 
    mutate(watch_rate = round(watch_rate, 2))
  
  # Only select segments within videos that have been watched at least
  # once This is the data frame that is used to make plots:
  aggregate_segment_df <- aggregate_segment_df[
    aggregate_segment_df$Students > 0,
  ]
  
  # Get the last segment for each video, for the purpose of creating a dummy
  # dataframe with zero counts for all segments in each video.
  last_segments <- aggregate_segment_df %>% 
    group_by(video_id) %>% 
    summarize(last_segment = mean(last_segment, na.rm = T))
  
  # For every video, create a row for each segment.
  for (video in 1:dim(last_segments)[1]) {
    video_segments <- expand_segments(
        last_segments$video_id[video],
        last_segments$last_segment[video]
    )
    if (video == 1) {
      all_segments <- video_segments
    } else {
      all_segments <- all_segments %>% 
        rbind(video_segments)
    }
  }
  
  # Isolate the missing segments.
  missing_segments <- all_segments %>% 
    mutate(segment = latest_segment) %>% 
    select(-latest_segment) %>% 
    anti_join(aggregate_segment_df)
  
  video_attributes <- aggregate_segment_df %>% 
    group_by(video_id) %>% 
    summarise(last_segment = unique(last_segment),
              course_order = unique(course_order),
              vid_length = unique(vid_length),
              video_name = unique(video_name),
              unique_views = unique(unique_views),
              Students = unique(Students))
  
  full_missing_segments <- missing_segments %>% 
    left_join(video_attributes) %>% 
    mutate(min_into_video = as.numeric(((segment*20)/60)+(1/6)),
           count = 0,
           watch_rate = 0,
           `Views per Student` = 0)
  
  aggregate_segment_df <- aggregate_segment_df %>% 
    rbind(full_missing_segments) %>% 
    arrange(course_order, segment)
  
  # Create dataframe with average watch rate of videos:
  avg_watch_rate_df <- aggregate_segment_df %>% 
    group_by(video_id) %>% 
    summarize(avg_watch_rate = round(mean(watch_rate), 2)) %>% 
    ungroup()
  
  # Obtain average watch rate:
  aggregate_segment_df <- aggregate_segment_df %>% 
    left_join(avg_watch_rate_df, 
              by = "video_id") %>% 
    dplyr::filter(!is.na(video_name))
  
  # Correcting course order:
  aggregate_segment_df <- aggregate_segment_df %>% 
    mutate(course_order = get_rank(course_order))
  
  # Making linear model to predict watch_rate
  model <- lm(watch_rate ~ course_order + min_into_video, aggregate_segment_df)
  
  # Finding most postiive and negative residuals:
  model_df <- data.frame(predict(model, interval = "confidence")) %>% 
    mutate(actual = aggregate_segment_df$watch_rate) %>% 
    mutate(residual = actual - fit) %>%
    mutate(negative_rank = get_rank(residual)) %>% 
    mutate(positive_rank = get_rank(-residual)) %>%
    mutate(top_negative = as.integer(negative_rank <= top_selection)) %>% 
    mutate(top_positive = as.integer(positive_rank <= top_selection)) %>% 
    mutate(high_low = case_when(.$top_positive == 1 ~ "High Watch Rate", 
                                .$top_negative == 1 ~ "Low Watch Rate", 
                                TRUE ~ "Normal"))
  
  # Adding positive and negative residual ranks to dataframe:
  aggregate_segment_df <- aggregate_segment_df %>% 
    mutate(high_low = model_df$high_low)
  
  return(aggregate_segment_df)
}

#' For a given video with a maximum segment, expand to create a dataframe
#'   with one row per segment. This is a recursive function.
#' @param video_d The video ID.
#' @param latest_segment The latest segment value. Typically begins with the 
#'   greatest segment value associated with the video in question.
#'
#' @return A dataframe with one row per segment in the video.
#'
#' @examples
#' expand_segments("lkjsdflkj1233113lkj23", 6)
expand_segments <- function(video_id, latest_segment) {
  
  if (latest_segment == 0) {
    return(data.frame(video_id = video_id, 
                      latest_segment = latest_segment))
  } else {
    current_segment <- data.frame(video_id = video_id, 
                                  latest_segment = latest_segment)
    expanded_segments <- rbind(current_segment,
                               expand_segments(video_id,
                                               latest_segment - 1))
  }
}

#' Obtains locations of chapter lines to be placed on visualizations
#' @param filt_segs Dataframe containing students that have been filtered by 
#'   selected demographics. Typically obtained via \code{filter_demographics()}
#'
#' @return \code{ch_markers}: List of values of where to place chapter lines on 
#'   visualizations
#'
#' @examples
#' get_ch_markers(filt_segs)
get_ch_markers <- function(filt_segs) {
  
  if (length(unique(filt_segs$index_chapter)) > 1) {
    
    max_course_order <- max(rank(unique(filt_segs$course_order)), na.rm = TRUE)
    
    video_ch_markers <- filt_segs %>% 
      group_by(video_id) %>% 
      summarize(index_chapter = unique(index_chapter), 
                course_order = unique(course_order)) %>% 
      ungroup() %>% 
      mutate(course_order = get_rank(course_order)) %>% 
      arrange(course_order) %>% 
      mutate(last_vid_in_ch = index_chapter != lead(index_chapter)) %>% 
      mutate(ch_marker = ifelse(last_vid_in_ch, 
                                max_course_order-course_order, 
                                NA)) %>%
      select(video_id, ch_marker)
    
    ch_markers <- unique(
      video_ch_markers$ch_marker[!is.na(video_ch_markers$ch_marker)]
    ) + 0.5
    
    return(ch_markers)
    
  } else {
    return(NA)
  }
  
}

#' Obtains dataframe with length of videos
#' @param filt_segs Dataframe containing students that have been filtered by 
#'   selected demographics. Typically obtained via \code{filter_demographics()}
#'
#' @return \code{vid_lengths}: Dataframe with the video lengths associated with 
#'   each video ID.
#'
#' @examples
#' get_video_lengths(filt_segs)
get_video_lengths <- function(filt_segs) {
  vid_lengths <- filt_segs %>% 
    group_by(video_id) %>% 
    summarise(`Video length (minutes)` = round(
      unique(max_stop_position/SECONDS_IN_MINUTE), 2
    ))
  
  return(vid_lengths)
}

#' Obtains video summary table to be used on shiny app
#' @param aggregate_df Dataframe containing students that have been filtered by 
#'   selected demographics. Typically obtained via \code{filter_demographics()}
#' @param vid_lengths Dataframe containing video ID's with their associated 
#'   video lengths. Typically obtained via \code{get_video_lengths()}
#'
#' @return \code{summary_table}: Dataframe relevant summary statistics for each 
#'   video.
#'
#' @examples
#' get_summary_table(filt_segs, vid_lengths)
get_summary_table <- function(aggregate_df, vid_lengths, avg_time_spent) {
  summary_tbl <- aggregate_df %>% 
    ungroup() %>% 
    group_by(video_id) %>% 
    summarize(`Avg Views per Student` = mean(watch_rate), 
              Students = unique(unique_views), 
              course_order = max(course_order), 
              video_name = unique(video_name)) %>% 
    mutate(`Avg Views per Student` = round(`Avg Views per Student`, 2)) %>% 
    left_join(vid_lengths, by = "video_id") %>% 
    left_join(avg_time_spent, by = "video_id") %>% 
    mutate(avg_time_spent = avg_time_spent/SECONDS_IN_MINUTE) %>% 
    mutate(time_spent_per_vid_length = round(
      avg_time_spent/`Video length (minutes)`, 2
    )) %>% 
    mutate(video_id = forcats::fct_reorder(video_id, course_order)) %>% 
    select(-video_id) %>% 
    select(video_name, everything()) %>% 
    arrange(desc(course_order)) %>% 
    rename(`Video Name` = video_name) %>%  
    select(-course_order, -avg_time_spent, -time_spent_per_vid_length)
  
  return(summary_tbl)
}

get_video_minute_breaks <- function(limits) {
  breaks <- seq(limits[1], limits[2], by = 1)
}

#' Obtains heatmap plot comparing videos against each other
#' @param filtered_segments Dataframe of segments and corresponding watch counts 
#'   filtered by demographics
#' @param module String of module (chapter) name to display
#' @param filtered_ch_markers List of values containing locations of where to 
#'   put chapter markers
#'
#' @return \code{g}: ggplot heatmap object
#'
#' @examples
#' get_video_comparison_plot(filtered_segments, module, filtered_ch_markers)
get_video_comparison_plot <- function(filtered_segments, 
                                      module, 
                                      filtered_ch_markers) {
  
  g <- ggplot(
    filtered_segments, 
    aes_string(fill = "`Students`", 
               x = "min_into_video", 
               y = "forcats::fct_reorder(video_id, course_order, .desc = TRUE)", 
               text = "paste0(video_name, \"<br>\",
                      watch_rate, \" times viewed per student\", \"<br>\",
                      count, \" times this segment was watched (raw)\", 
                      \"<br>\", unique_views, 
                      \" students started this video\")")
  ) +
    geom_tile() + 
    theme(axis.title.y = element_blank(), 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggthemes::theme_few(base_family = "GillSans") + 
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) + 
    xlab("Length of video (minutes)") + 
    ylab("Video") + 
    viridis::scale_fill_viridis(
      name = "Unique viewers"
    ) +
    scale_x_continuous(
      breaks = seq(0,
                   max(filtered_segments$min_into_video, na.rm = T),
                   max(
                     round(
                       max(
                         filtered_segments$min_into_video, na.rm = T)/10
                     ),
                     1
                   )
      )
    )
  
  if (module == "All") {
    g <- g + 
      geom_hline(yintercept = filtered_ch_markers)
  }
  
  return(g)
}

#' Obtains heatmap plot comparing segments against each other
#' @param filtered_segments Dataframe of segments and corresponding watch counts 
#'   filtered by demographics
#' @param module String of module (chapter) name to display
#' @param filtered_ch_markers List of values containing locations of where to 
#'   put chapter markers
#'
#' @return \code{g}: ggplot heatmap object
#'
#' @examples
#' get_segment_comparison_plot(filtered_segments, module, filtered_ch_markers)
get_segment_comparison_plot <- function(filtered_segments, 
                                        module, 
                                        filtered_ch_markers) {
  g <- ggplot(filtered_segments, aes_string(
    fill = "watch_rate", 
    x = "min_into_video", 
    y = "forcats::fct_reorder(video_id, course_order, .desc = TRUE)", 
    text = "paste0(video_name, \"<br>\",watch_rate, \" views per student\", 
           \"<br>\", count, \" times this segment was watched (raw)\", \"<br>\",
           unique_views, \" students started this video\")")) + 
    geom_tile() + 
    theme(axis.title.y = element_blank(), 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggthemes::theme_few(base_family = "GillSans") + 
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) + 
    xlab("Position in video (minutes)") + 
    ylab("Video") + 
    viridis::scale_fill_viridis(
      name = "Views per learner<br>who started the<br>video ('watch rate')"
    ) +
    scale_x_continuous(
      breaks = seq(0,
                   max(filtered_segments$min_into_video, na.rm = T),
                   max(
                     round(
                       max(
                         filtered_segments$min_into_video, na.rm = T)/10
                     ),
                     1
                   )
      )
    )
  
  if (module == "All") {
    g <- g + 
      geom_hline(yintercept = filtered_ch_markers)
  }
  
  return(g)
}


#' Obtains heatmap plot highlighting which segments have abnormally high or low 
#'   watch rates
#' @param filtered_segments Dataframe of segments and corresponding watch counts 
#'   filtered by demographics
#' @param module String of module (chapter) name to display
#' @param filtered_ch_markers List of values containing locations of where to 
#'   put chapter markers
#'
#' @return \code{g}: ggplot heatmap object
#'
#' @examples
#' get_high_low_plot(filtered_segments, module, filtered_ch_markers)
get_high_low_plot <- function(filtered_segments, module, filtered_ch_markers) {
  
  g <- ggplot(filtered_segments) + 
    geom_tile(
      aes_string(fill = "high_low", 
                 x = "round(min_into_video, digits = 10)", 
                 y = "forcats::fct_reorder(video_id, course_order, .desc = TRUE)", 
                 text = "paste0(video_name, \"<br>\",
                      watch_rate, \" times viewed per student\", \"<br>\",
                      count, \" times this segment was watched (raw)\", 
                      \"<br>\", unique_views, 
                      \" students started this video\")")) + 
    theme(axis.title.y = element_blank(), 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggthemes::theme_few(base_family = "GillSans") + 
    theme(axis.text.y = element_blank(), axis.ticks.y = element_blank()) + 
    xlab("Position in video (minutes)") + 
    ylab("Video") + 
    scale_fill_manual(values = c("#F8E85D", "#488C93", "#3D0752"),
                      name = "Legend") +
    scale_x_continuous(
      breaks = seq(0,
                   max(filtered_segments$min_into_video, na.rm = T),
                   max(
                     round(
                       max(
                         filtered_segments$min_into_video, na.rm = T)/10
                     ),
                     1
                   )
      )
    )
  
  if (module == "All") {
    g <- g + geom_hline(yintercept = filtered_ch_markers)
  }
  
  return(g)
}

#' Obtains heatmap plot highlighting which segment has been watched up until on 
#'   average
#' @param filtered_segments Dataframe of segments and corresponding watch counts 
#'   filtered by demographics
#' @param module String of module (chapter) name to display
#' @param filtered_ch_markers List of values containing locations of where to 
#'   put chapter markers
#'
#' @return \code{g}: ggplot heatmap object
#'
#' @examples
#' get_up_until_plot(filtered_segments, module, filtered_ch_markers)
get_up_until_plot <- function(filtered_segments, module, filtered_ch_markers) {
  g <- ggplot(filtered_segments, 
              aes_string(fill = "up_until", 
                         x = "min_into_video", 
                         y = "video_id", 
                         text = "paste0(video_name, \"<br>\",watch_rate, 
                                \" views per student\", \"<br>\",count, \" 
                                times this segment was watched\", \"<br>\", 
                                unique_views, \" 
                                students started this video\")")) + 
    geom_tile() + 
    theme(axis.title.y = element_blank(), 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggthemes::theme_few(base_family = "GillSans") + 
    theme(axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    xlab("Position in video (minutes)") + 
    ylab("Video") + 
    scale_fill_gradient(low = "gray86", high = "skyblue", guide = FALSE) +
    scale_x_continuous(
      breaks = seq(0,
                   max(filtered_segments$min_into_video, na.rm = T),
                   max(
                     round(
                       max(
                         filtered_segments$min_into_video, na.rm = T)/10
                     ),
                     1
                   )
      )
    )
  
  if (module == "All") {
    g <- g + 
      geom_hline(yintercept = filtered_ch_markers)
  }
  
  return(g)
}

#' Returns the ranking of a vector x
#' @param x A vector of numeric values
#'
#' @return \code{g}: The ranking of the values within x
#'
#' @examples
#' get_rank(c(10, 20, 20, 22, 5))
get_rank <- function(x) {
  x_unique <- unique(x)
  ranks <- rank(x_unique)
  ranked <- ranks[match(x, x_unique)]
  return(ranked)
}

#' Returns a dataframe with the average time learners spent on each video
#' @param filtered_segments Dataframe of segments and corresponding watch counts 
#'   filtered by demographics
#'
#' @return \code{g}: A dataframe with the average time learners spent on each 
#'   video
#'
#' @examples
#' get_avg_time_spent(filtered_segments)
get_avg_time_spent <- function(filtered_segments) {
  
  avg_time_spent <- filtered_segments %>% 
    group_by(user_id, video_id) %>% 
    summarize(time_spent = sum(count) * SEGMENT_SIZE) %>% 
    ungroup() %>% 
    group_by(video_id) %>% summarize(avg_time_spent = mean(time_spent))
  
  return(avg_time_spent)
}

#' Appends 'All' to the list of chapter names to be used in the filtering panel
#'
#' @param chap_name A list of chapter names belonging to the course
#'
#' @return The list of chapter names appended with 'All'
#'
#' @examples get_module_options(c('Chapter 1', 'Chapter 2', 'Chapter 3'))
get_module_options <- function(chap_name) {
  module_options <- append("All", chap_name)
  return(module_options)
}


#' Make a heatmap showing the number of unique viewers across time.
#' 
#' @param filt_events A dataframe containing the video events filtered down
#'   by the user's selected inputs.
#' @param axis A dataframe containing information about each video.
#' @param module The selected module, as defined by the user.
#' @param ch_markers A dataframe containing the locations of each chapter
#'   separator.
#' 
#' @return A ggplot object showing the number of unique viewers across time.
#' @import dplyr
#' @import ggplot2
#' @export
make_video_time_plot <- function(filt_events, axis, module, ch_markers) {
  
  all_dates <- seq(
    from = min(as.Date(filt_events$time), na.rm = T), 
    to = max(as.Date(filt_events$time), na.rm = T), 
    by = 1
  )
  all_videos <- unique(
    filt_events$video_name
  )[!is.na(unique(filt_events$video_name))]
  
  complete_dates <- data.frame(
    video_name = sort(rep(all_videos, times = length(all_dates))),
    date = rep(all_dates, times = length(all_videos))
  ) %>% 
    dplyr::left_join(axis)
  
  prepared <- filt_events %>% 
    dplyr::group_by(video_name, index_video, date = as.Date(time)) %>% 
    dplyr::summarise(viewers = n_distinct(user_id)) %>%
    dplyr::filter(!is.na(video_name)) %>% 
    dplyr::right_join(complete_dates) %>% 
    dplyr::mutate(viewers = dplyr::case_when(
      !is.na(viewers) ~ viewers,
      TRUE ~ as.integer(0)
    ))
  
  g <- ggplot2::ggplot(prepared) +
    ggplot2::geom_tile(
      ggplot2::aes_string(
        x = "date", 
        y = "forcats::fct_reorder(video_name, index_video, .desc = T)", 
        fill = "viewers",
        text = "paste0(video_name, \"<br>\",
                date, \"<br>\",
                viewers,\" viewers\")"
      )
    ) +
    viridis::scale_fill_viridis(
      name = "Unique viewers"
    ) +
    theme(axis.title.y = element_blank(), 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggthemes::theme_few(base_family = "GillSans") + 
    ggplot2::theme(axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()) + 
    ggplot2::xlab("Date") + 
    ggplot2::ylab("Video")
  
  if (module == "All") {
    g <- g + ggplot2::geom_hline(yintercept = ch_markers)
  }
  
  return(g)
  
}