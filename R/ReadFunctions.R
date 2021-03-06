#' Read a whole directory of '.tcx' files.
#'
#' @param home_path The path to read the files from.
#'
#' @return Tidy data frame of all runs
#' @export
#' @seealso You can do a bulk download of all your Garmin runs at
#' \url{http://www.sideburn.org/garmin/}
#' @importFrom magrittr %>%
#'
#' @examples
read_tcx_directory <- function(home_path) {
  df_erg <- tibble::data_frame(path = dir(path = home_path, full.names = TRUE)) %>%
    filter(stringr::str_detect(path, ".tcx"))

  df_erg <- df_erg %>%
    dplyr::mutate(run_data = purrr::map(path, purrr::possibly(read_tcx, NULL)),
      is_null = purrr::map_lgl(run_data, is.null)) %>%
    dplyr::filter(!is_null) %>%
    tidyr::unnest(run_data) %>%
    dplyr::mutate(measurement = as.factor(measurement),
      type = as.factor(type)) %>%
    dplyr::select(-is_null)
}

#' Read a '.tcx' file.
#'
#' The function \code{read_tcx_run} reads a '.tcx' file from a given path and
#' returns a tidy data frame of the run.
#'
#' In the \code{path}, you have to replace the '\' by '/',
#'  if you are using a windows system.
#'
#' @param path The path to read the file from
#'
#' @return Tidy data frame of the run
#' @export
#'
#' @examples
read_tcx <- function(path) {
  #Read xml and get all nodes of the activity
  xml_run <- xml2::read_xml(x = path, encoding = "ISO-8859-1") %>%
    xml2::xml_ns_strip()

  type_act <- xml2::xml_find_first(xml_run, ".//Activity") %>%
    xml2::xml_attr(attr = "Sport")

  track_points <- xml2::xml_find_all(x = xml_run, xpath = ".//Trackpoint")

  df_nodes <- tibble::data_frame(nodes =
      track_points %>%
      purrr::map(xml2::xml_find_all, xpath = ".//*[not(*)]"))

  #Filter activities without any trackpoints
  if(length(track_points) == 0) {
    return(NULL)
  }

  #Turn nodes into tidy data frame
  df_erg <- df_nodes %>%
    dplyr::mutate(
      measurement = purrr::map(nodes, xml2::xml_name),
      value = purrr::map(nodes, xml2::xml_text),
      time = purrr::map2_chr(measurement, value, function(x, y) y[x == "Time"])) %>%
    dplyr::select(-nodes) %>%
    tidyr::unnest(measurement, value) %>%
    dplyr::filter(measurement != "Time") %>%
    dplyr::mutate(type = type_act)

  #Further preprocessing
  df_erg <- df_erg %>%
    tidyr::separate(time, into = c("date", "time"), sep = "T") %>%
    tidyr::unite(col = datetime, date, time, remove = FALSE, sep = " ") %>%
    dplyr::mutate(
      value = as.numeric(value), date = as.Date(date),
      datetime = as.POSIXct(datetime),
      measurement = dplyr::if_else(measurement == "Value", "BPM", measurement))
  return(df_erg)
}


