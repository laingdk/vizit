% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/video_wrangling.R
\name{get_start_end_df}
\alias{get_start_end_df}
\title{Obtains start and end times for video events}
\usage{
get_start_end_df(data)
}
\arguments{
\item{data}{Dataframe containing tracklog data of students. This is obtained 
typically through \code{prepare_video_data()}}
}
\value{
\code{start_end_df}: Original dataframe with \code{start} and 
  \code{end} columns
}
\description{
Parses dataframe and adds columns \code{start} and \code{end} 
  showing the start and end time that a user watched a video
}
\examples{
get_start_end_df(data = data)
}
