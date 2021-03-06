% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/forum_server.R
\name{update_forum_data}
\alias{update_forum_data}
\title{Update the post, view, and author counts for the selected filters.}
\usage{
update_forum_data(forum_posts, forum_views, forum_elements, activity_level,
  gender, registration_status, category)
}
\arguments{
\item{forum_posts}{The forum posts dataframe passed in from the wrangling 
script.}

\item{forum_views}{The forum views dataframe passed in from the wrangling 
script.}

\item{forum_elements}{The forum elements dataframe passed in from the 
wrangling script.}

\item{activity_level}{The activity level of the students.}

\item{gender}{The gender of the students.}

\item{registration_status}{The registration status of the students.}

\item{category}{The forum category.}
}
\value{
\code{filtered_forum_data} A dataframe with one row per subcategory 
  (or category), and counts for each variable.
}
\description{
Update the post, view, and author counts for the selected filters.
}
\examples{
update_forum_data(
  wrangled_forum_posts,
  wrangled_forum_views, 
  filtered_forum_elements(), 
  "over_5_hr", 
  "other", 
  "audit", 
  "All"
)
}
