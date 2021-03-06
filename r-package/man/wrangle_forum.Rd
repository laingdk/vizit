% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/forum_wrangling.R
\name{wrangle_forum}
\alias{wrangle_forum}
\title{Write the forum posts and forum words to csv.}
\usage{
wrangle_forum(posts_input_path, views_input_path, searches_input_path,
  json_input_path, xml_input_path, posts_output_path, words_output_path,
  views_output_path, searches_output_path, elements_output_path)
}
\arguments{
\item{posts_input_path}{The path to the CSV file containing the forum posts 
data.}

\item{views_input_path}{The path to the CSV file containing the forum reads 
data.}

\item{searches_input_path}{The path to the CSV file containing the forum 
searches data.}

\item{json_input_path}{The path to the JSON file containing data on all 
course elements.}

\item{xml_input_path}{The path to the XML file containing data on the course 
structure.}

\item{posts_output_path}{The desired path to which to write the prepared 
forum posts dataframe.}

\item{words_output_path}{The desired path to which to write the prepared 
forum words dataframe.}

\item{views_output_path}{The desired path to which to write the prepared 
forum views dataframe.}

\item{searches_output_path}{The desired path to which to write the prepared 
forum searches dataframe.}

\item{elements_output_path}{The desired path to which to write the prepared 
forum elements dataframe.}
}
\value{
None.
}
\description{
Write the forum posts and forum words to csv.
}
\examples{
wrangle_forum(csv_path, json_path, xml_path)
}
