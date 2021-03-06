store_outputs <- function(target, value, meta, config) {
  # Failed targets need to stay invalidated,
  # even when `config$keep_going` is `TRUE`.
  if (inherits(meta$error, "error")) {
    return()
  }
  console_store(target = target, config = config)
  layout <- config$layout[[target]]
  if (is.null(meta$command)) {
    meta$command <- layout$command_standardized
  }
  if (is.null(meta$dependency_hash)) {
    meta$dependency_hash <- dependency_hash(target = target, config = config)
  }
  if (is.null(meta$input_file_hash)) {
    meta$input_file_hash <- input_file_hash(target = target, config = config)
  }
  if (!is.null(meta$trigger$change)) {
    config$cache$set(
      key = target, value = meta$trigger$value, namespace = "change"
    )
    meta$trigger$value <- NULL
  }
  store_output_files(layout$deps_build$file_out, meta, config)
  if (length(file_out) || is.null(file_out)) {
    meta$output_file_hash <- output_file_hash(
      target = target, config = config)
  }
  meta$name <- target
  store_single_output(
    target = target,
    value = value,
    meta = meta,
    config = config,
    verbose = TRUE
  )
  set_progress(
    target = target,
    meta = meta,
    value = "done",
    config = config
  )
}

store_single_output <- function(target, value, meta, config, verbose = FALSE) {
  if (meta$isfile) {
    store_file(
      target = target,
      meta = meta,
      config = config
    )
  } else if (is.function(value)) {
    store_function(
      target = target,
      value = value,
      meta = meta,
      config = config
    )
  } else {
    store_object(
      target = target,
      value = value,
      meta = meta,
      config = config
    )
  }
  finalize_storage(
    target = target,
    value = value,
    meta = meta,
    config = config,
    verbose = verbose
  )
}

finalize_storage <- function(target, value, meta, config, verbose) {
  meta <- finalize_times(
    target = target,
    meta = meta,
    config = config
  )
  config$cache$set(key = target, value = meta, namespace = "meta")
  if (!meta$imported && verbose) {
    console_time(target, meta, config)
  }
}

store_object <- function(target, value, meta, config) {
  config$cache$set(key = target, value = value)
}

store_file <- function(target, meta, config) {
  store_object(
    target = target,
    value = safe_rehash_file(target = target, config = config),
    meta = meta,
    config = config
  )
}

store_output_files <- function(files, meta, config) {
  meta$isfile <- TRUE
  for (file in files) {
    meta$name <- file
    meta$mtime <- file.mtime(decode_path(file, config))
    meta$isfile <- TRUE
    store_single_output(
      target = file,
      meta = meta,
      config = config
    )
  }
}

store_function <- function(target, value, meta, config) {
  if (meta$imported) {
    value <- standardize_imported_function(value)
    value <- c(value, meta$dependency_hash)
  }
  store_object(target, value, meta, config)
}

store_failure <- function(target, meta, config) {
  set_progress(
    target = target,
    meta = meta,
    value = "failed",
    config = config
  )
  subspaces <- intersect(c("messages", "warnings", "error"), names(meta))
  set_in_subspaces(
    key = target,
    values = meta[subspaces],
    subspaces = subspaces,
    namespace = "meta",
    cache = config$cache
  )
}
