# Interface text of the Shiny application in Indonesian and English.

app_text <- list(
  id = list(
    title = "rcli: Indikator Komposit Pendahulu",
    progress = "Kemajuan",
    need_prev = "Selesaikan langkah sebelumnya terlebih dahulu.",
    next_step = "Langkah berikutnya",
    s1 = "1. Data", s2 = "2. Metadata kandidat", s3 = "3. Spesifikasi",
    s4 = "4. Siklus", s5 = "5. Titik balik", s6 = "6. Pemilahan",
    s7 = "7. Komposit", s8 = "8. Validasi dan mutu",
    s9 = "9. Indeks sejalan", s10 = "10. Ekspor",
    h1 = paste("Muat seri acuan (misalnya PDB atau indeks produksi) dan seri",
               "kandidat. Berkas CSV: satu kolom per seri; kolom pertama",
               "boleh berisi tanggal (2001-01, 2001-01-01, atau 2001Q1)."),
    h2 = paste("OECD mensyaratkan rasional ekonomi untuk setiap komponen:",
               "statistik tidak menggantikannya. Isi rasional, tipe variabel",
               "(aliran: jumlah selama periode; stok: posisi akhir periode;",
               "rata-rata: tingkat rata-rata periode), dan sumber data setiap",
               "kandidat."),
    h3 = paste("Semua pilihan metode dikumpulkan dalam satu spesifikasi.",
               "Ambang bawaan sudah dikalibrasi dengan simulasi Monte Carlo."),
    h4 = paste("Setiap seri ditransformasi (log), dibersihkan dari pencilan,",
               "disaring menjadi siklus, lalu dinormalisasi."),
    h5 = paste("Puncak dan lembah ditentukan dengan aturan Bry-Boschan",
               "(bulanan) atau Harding-Pagan BBQ (triwulanan)."),
    h6 = paste("Setiap kandidat dibandingkan dengan seri acuan dan diberi",
               "kelas pendahulu, sejalan, tertinggal, atau ditolak."),
    h7 = paste("Kandidat pendahulu digabung menjadi indeks komposit. Mode",
               "otomatis membuang komponen satu per satu sampai komposit",
               "lolos uji."),
    h8 = paste("Kartu skor menilai komposit dari tiga sisi: titik balik,",
               "kemampuan prediksi, dan uji luar sampel (bias seleksi)."),
    h9 = paste("Kandidat sejalan digabung menjadi indeks sejalan yang",
               "menggambarkan posisi siklus saat ini. Indeks diuji ketepatan",
               "waktunya (bukan lead-nya) dan dapat menjadi seri acuan",
               "bulanan pengganti PDB triwulanan. Langkah ini hanya",
               "memerlukan langkah 6."),
    h10 = paste("Unduh hasil setiap langkah dan kode R yang mereproduksi",
                "analisis ini."),
    run1 = "Muat data", run2 = "Bentuk himpunan kandidat",
    run3 = "Simpan spesifikasi", run4 = "Ekstraksi siklus",
    run5 = "Tentukan titik balik", run6 = "Pilah kandidat",
    run7 = "Bentuk komposit", run8 = "Jalankan uji luar sampel",
    run9 = "Bentuk indeks sejalan",
    source = "Sumber data", src_example_m = "Contoh simulasi bulanan",
    src_example_q = "Contoh simulasi triwulanan", src_upload = "Unggah CSV",
    seed = "Benih acak", file = "Berkas CSV", freq = "Frekuensi",
    freq_auto = "Otomatis dari kolom tanggal", monthly = "Bulanan",
    quarterly = "Triwulanan",
    start = "Awal data jika tanpa kolom tanggal (tahun-periode, mis. 2000-1)",
    reference = "Seri acuan", rationale = "Rasional ekonomi",
    data_source = "Sumber", none = "(belum diisi)",
    var_type = "Tipe variabel", type_flow = "Aliran",
    type_stock = "Stok", type_average = "Rata-rata",
    method = "Metode",
    method_rcli = "rcli (bawaan, ambang terkalibrasi)",
    method_oecd = "Persis OECD (Gyomai dan Guidetti 2012)",
    method_help = paste(
      "Metode OECD memakai pencilan TRAMO dengan prakiraan, uji log,",
      "klasifikasi median lead (sejalan \u00b12 bulan), penggeseran lag, dan",
      "agregasi laju pertumbuhan berantai. Penyaring, metode agregasi,",
      "transformasi, ambang pencilan, dan ambang klasifikasi di kolom kanan",
      "tidak dipakai; taraf nyata, AUC minimum, dan pengaturan loop tetap",
      "dipakai."),
    filter = "Penyaring siklus", aggregator = "Metode agregasi",
    transform = "Transformasi", seasonal = "Penyesuaian musiman X-13",
    seasonal_missing = "(paket seasonal belum terpasang)",
    outlier = "Ambang pencilan (skor-z robust)",
    min_lead = "Lead minimum korelasi silang (periode)",
    min_median_lead = "Median lead minimum di titik balik",
    min_consistency = "Pangsa minimum titik balik yang didahului",
    max_missed = "Pangsa maksimum titik balik terlewat",
    max_extra = "Pangsa maksimum titik balik ekstra",
    alpha = "Taraf nyata uji", min_auc = "AUC minimum",
    min_components = "Jumlah komponen minimum",
    max_iter = "Iterasi maksimum loop seleksi",
    oos_cutoffs = "Titik potong uji luar sampel (tahun, pisahkan dengan koma)",
    series = "Pilih seri",
    overview = "Semua seri (indeks, nilai pertama = 100)",
    data_summary = "Ringkasan data", meta_table = "Metadata kandidat",
    cycle_pair = "Siklus seri terpilih dan seri acuan",
    cycles_all = "Siklus ternormalisasi semua seri",
    steps_log = "Langkah pengolahan",
    tp_plot = "Titik balik (arsiran: kontraksi seri acuan)",
    tp_counts = "Jumlah titik balik", tp_table = "Daftar titik balik",
    leads_plot = "Lead korelasi silang menurut kelas",
    ccf_plot = "Korelasi silang pada setiap lead",
    aligned = "Kandidat digeser sebesar lead-nya",
    assess_table = "Hasil pemilahan",
    reasons = "Kriteria pendahulu yang tidak terpenuhi",
    comp_mode = "Cara memilih komponen", mode_auto = "Otomatis (loop seleksi)",
    mode_manual = "Manual", components = "Komponen",
    composite_plot = "Indikator komposit dan siklus acuan",
    weights = "Bobot komponen", components_plot = "Komponen dan komposit",
    audit = "Jejak keputusan loop seleksi",
    verdict = "Vonis mutu", good = "BAIK", acceptable = "LAYAK",
    weak = "LEMAH",
    good_note = "Semua kriteria titik balik, prediksi, dan luar sampel lolos.",
    acceptable_note = paste("Kriteria dalam sampel lolos; jalankan uji luar",
                            "sampel sebelum mengandalkan lead-nya."),
    weak_note = "Ada kriteria yang tidak lolos; lihat kartu skor.",
    scorecard = "Kartu skor mutu",
    probability = "Peluang kontraksi (arsiran: kontraksi aktual)",
    roc = "Kurva ROC", sb_plot = "Lead dalam sampel dan sesudah titik potong",
    sb_table = "Uji bias seleksi", validation = "Ringkasan validasi",
    no_cutoffs = "Isi titik potong di langkah 3 untuk uji luar sampel.",
    dl_cli = "Indikator komposit (CSV)", dl_assess = "Hasil pemilahan (CSV)",
    dl_audit = "Jejak keputusan (CSV)", dl_quality = "Kartu skor (CSV)",
    dl_rds = "Objek CliResult (RDS)", dl_script = "Skrip R",
    dl_cci = "Indeks sejalan (CSV)",
    dl_cci_quality = "Kartu skor indeks sejalan (CSV)",
    cci_plot = "Indeks sejalan dan siklus acuan",
    acceptable_note_cci = paste("Kriteria dalam sampel lolos; jalankan uji",
                                "luar sampel sebelum mengandalkan ketepatan",
                                "waktunya."),
    need_cci = "Bentuk indeks sejalan terlebih dahulu.",
    no_coincident = paste(
      "Tidak ada kandidat sejalan; ubah spesifikasi atau pilih komponen",
      "secara manual."),
    code = "Kode R yang setara", no_leaders = paste(
      "Tidak ada kandidat pendahulu; ubah spesifikasi atau pilih komponen",
      "secara manual."),
    loaded = "Data dimuat", error = "Galat"
  ),
  en = list(
    title = "rcli: Composite Leading Indicator",
    progress = "Progress",
    need_prev = "Complete the previous step first.",
    next_step = "Next step",
    s1 = "1. Data", s2 = "2. Candidate metadata", s3 = "3. Specification",
    s4 = "4. Cycles", s5 = "5. Turning points", s6 = "6. Classification",
    s7 = "7. Composite", s8 = "8. Validation and quality",
    s9 = "9. Coincident index", s10 = "10. Export",
    h1 = paste("Load the reference series (for example GDP or industrial",
               "production) and the candidate series. CSV file: one column",
               "per series; the first column may hold dates (2001-01,",
               "2001-01-01 or 2001Q1)."),
    h2 = paste("The OECD requires an economic rationale for every component;",
               "statistics do not replace it. Fill in the rationale, the",
               "variable type (flow: amount over the period; stock: position",
               "at its end; average: mean level over it) and the data source",
               "of each candidate."),
    h3 = paste("All methodological choices are collected in one",
               "specification. Default thresholds were calibrated by Monte",
               "Carlo simulation."),
    h4 = paste("Each series is transformed (log), cleaned of outliers,",
               "filtered into a cycle and normalised."),
    h5 = paste("Peaks and troughs are dated with the Bry-Boschan (monthly)",
               "or Harding-Pagan BBQ (quarterly) rules."),
    h6 = paste("Each candidate is compared with the reference and classified",
               "as leading, coincident, lagging or rejected."),
    h7 = paste("Leading candidates are combined into a composite index. The",
               "automatic mode drops components one at a time until the",
               "composite passes."),
    h8 = paste("The scorecard judges the composite on turning points,",
               "prediction and an out-of-sample (selection bias) check."),
    h9 = paste("Coincident candidates are combined into a coincident index",
               "that shows where the cycle is now. The index is tested for",
               "timing (not lead) and can replace quarterly GDP as a monthly",
               "reference series. This step needs only step 6."),
    h10 = "Download the results of every step and R code reproducing them.",
    run1 = "Load data", run2 = "Build candidate set",
    run3 = "Save specification", run4 = "Extract cycles",
    run5 = "Date turning points", run6 = "Classify candidates",
    run7 = "Build composite", run8 = "Run out-of-sample check",
    run9 = "Build coincident index",
    source = "Data source", src_example_m = "Simulated monthly example",
    src_example_q = "Simulated quarterly example", src_upload = "Upload CSV",
    seed = "Random seed", file = "CSV file", freq = "Frequency",
    freq_auto = "Detect from date column", monthly = "Monthly",
    quarterly = "Quarterly",
    start = "Start if there is no date column (year-period, e.g. 2000-1)",
    reference = "Reference series", rationale = "Economic rationale",
    data_source = "Source", none = "(not given)",
    var_type = "Variable type", type_flow = "Flow",
    type_stock = "Stock", type_average = "Average",
    method = "Method",
    method_rcli = "rcli (default, calibrated thresholds)",
    method_oecd = "Exactly as the OECD (Gyomai and Guidetti 2012)",
    method_help = paste(
      "The OECD method uses TRAMO outliers with forecasts, the log test,",
      "the median-lead classification (coincident within \u00b12 months),",
      "lag-shifting and chained average growth. The filter, aggregation",
      "method, transformation, outlier threshold and the classification",
      "thresholds on the right are not used; the significance level, the",
      "minimum AUC and the loop settings still apply."),
    filter = "Cycle filter", aggregator = "Aggregation method",
    transform = "Transformation", seasonal = "X-13 seasonal adjustment",
    seasonal_missing = "(package seasonal not installed)",
    outlier = "Outlier threshold (robust z-score)",
    min_lead = "Minimum cross-correlation lead (periods)",
    min_median_lead = "Minimum median lead at turning points",
    min_consistency = "Minimum share of turning points led",
    max_missed = "Maximum share of missed turning points",
    max_extra = "Maximum share of extra turning points",
    alpha = "Significance level", min_auc = "Minimum AUC",
    min_components = "Minimum number of components",
    max_iter = "Maximum iterations of the selection loop",
    oos_cutoffs = "Out-of-sample cut-offs (years, comma separated)",
    series = "Choose a series",
    overview = "All series (index, first value = 100)",
    data_summary = "Data summary", meta_table = "Candidate metadata",
    cycle_pair = "Cycle of the chosen series and the reference",
    cycles_all = "Normalised cycles of all series",
    steps_log = "Processing steps",
    tp_plot = "Turning points (shaded: reference contractions)",
    tp_counts = "Number of turning points", tp_table = "Turning points",
    leads_plot = "Cross-correlation lead by class",
    ccf_plot = "Cross-correlation at each lead",
    aligned = "Candidate moved by its lead",
    assess_table = "Classification",
    reasons = "Leading criteria not met",
    comp_mode = "How to choose components",
    mode_auto = "Automatic (selection loop)", mode_manual = "Manual",
    components = "Components",
    composite_plot = "Composite leading indicator and reference cycle",
    weights = "Component weights", components_plot = "Components and composite",
    audit = "Audit log of the selection loop",
    verdict = "Quality verdict", good = "GOOD", acceptable = "ACCEPTABLE",
    weak = "WEAK",
    good_note = paste("All turning-point, prediction and out-of-sample",
                      "criteria pass."),
    acceptable_note = paste("In-sample criteria pass; run the out-of-sample",
                            "check before relying on the lead."),
    weak_note = "Some criteria fail; see the scorecard.",
    scorecard = "Quality scorecard",
    probability = "Probability of contraction (shaded: actual contractions)",
    roc = "ROC curve", sb_plot = "Lead in sample and after the cut-off",
    sb_table = "Selection-bias check", validation = "Validation summary",
    no_cutoffs = "Give cut-offs in step 3 to run the out-of-sample check.",
    dl_cli = "Composite indicator (CSV)", dl_assess = "Classification (CSV)",
    dl_audit = "Audit log (CSV)", dl_quality = "Scorecard (CSV)",
    dl_rds = "CliResult object (RDS)", dl_script = "R script",
    dl_cci = "Coincident index (CSV)",
    dl_cci_quality = "Coincident index scorecard (CSV)",
    cci_plot = "Coincident index and reference cycle",
    acceptable_note_cci = paste("In-sample criteria pass; run the",
                                "out-of-sample check before relying on the",
                                "timing."),
    need_cci = "Build the coincident index first.",
    no_coincident = paste(
      "No candidate is coincident; change the specification or choose",
      "components manually."),
    code = "Equivalent R code", no_leaders = paste(
      "No candidate is leading; change the specification or choose",
      "components manually."),
    loaded = "Data loaded", error = "Error"
  )
)

# Translation helper: a function returning the text of a key.
app_translator <- function(language) {
  dict <- app_text[[language]]
  function(key) {
    out <- dict[[key]]
    if (is.null(out)) key else out
  }
}

# Phrases that appear in tables and plots, keyed by their English text.
app_phrases_id <- c(
  # classes and groups
  leading = "pendahulu", coincident = "sejalan", lagging = "tertinggal",
  rejected = "ditolak", "turning points" = "titik balik",
  prediction = "prediksi", "out of sample" = "luar sampel",
  information = "informasi", pass = "lolos", fail = "GAGAL", info = "info",
  peak = "puncak", trough = "lembah",
  # scorecard criteria
  "matched turning points" = "titik balik berpasangan",
  "cross-correlation lead" = "lead korelasi silang",
  "median lead at turning points" = "median lead di titik balik",
  "share of turning points led" = "pangsa titik balik yang didahului",
  "share of missed turning points" = "pangsa titik balik terlewat",
  "share of extra turning points" = "pangsa titik balik ekstra",
  concordance = "konkordansi",
  "Granger causality p-value" = "nilai-p kausalitas Granger",
  "area under the ROC curve" = "luas di bawah kurva ROC (AUC)",
  "quadratic probability score" = "skor probabilitas kuadratik (QPS)",
  "Pesaran-Timmermann p-value" = "nilai-p Pesaran-Timmermann",
  "median lead after cut-offs" = "median lead sesudah titik potong",
  "share of later turning points led" =
    "pangsa titik balik sesudah titik potong yang didahului",
  "in-sample minus later lead" = "lead dalam sampel dikurangi lead sesudahnya",
  "lead within the OECD target range" = "lead dalam rentang sasaran OECD",
  "mean lead at turning points" = "rata-rata lead di titik balik",
  "standard deviation of the lead" = "simpangan baku lead",
  "peak cross-correlation" = "puncak korelasi silang",
  "close to median lead" = "dekat dengan median lead",
  "cross-correlation lag" = "lag korelasi silang",
  "lag of the cross-correlation peak" = "lag puncak korelasi silang",
  "0 for a coincident index" = "0 untuk indeks sejalan",
  "share of later turning points within the band" =
    "pangsa titik balik sesudah titik potong yang berada dalam pita",
  "absolute in-sample minus later lead" =
    "selisih mutlak lead dalam sampel dan sesudahnya",
  within = "dalam",
  # audit log and selection bias
  "initial composite of all leading candidates" =
    "komposit awal dari semua kandidat pendahulu",
  "accepted: all criteria met" = "diterima: semua kriteria terpenuhi",
  "stopped: minimum number of components reached" =
    "berhenti: jumlah komponen minimum tercapai",
  "stopped: maximum number of iterations" =
    "berhenti: iterasi maksimum tercapai",
  "manual selection" = "pemilihan manual",
  "no leading candidates" = "tidak ada kandidat pendahulu",
  "initial index of all coincident candidates" =
    "indeks awal dari semua kandidat sejalan",
  "initial index of the given components" =
    "indeks awal dari komponen yang dipilih",
  "kept: selection switched off" = "dipertahankan: seleksi dimatikan",
  "no coincident candidates" = "tidak ada kandidat sejalan",
  "no coincident candidate before the cut-off" =
    "belum ada kandidat sejalan sebelum titik potong",
  "training window too short" = "jendela latih terlalu pendek",
  "no leading candidate before the cut-off" =
    "belum ada kandidat pendahulu sebelum titik potong",
  # table headers
  series = "seri", start = "awal", end = "akhir", observations = "observasi",
  missing = "hilang", peaks = "puncak", troughs = "lembah",
  period = "periode", type = "jenis", value = "nilai",
  candidate = "kandidat", class = "kelas", rationale = "rasional",
  lead = "lead", median = "median", led = "didahului", missed = "terlewat",
  extra = "ekstra", granger_p = "p Granger", group = "kelompok",
  criterion = "kriteria", threshold = "ambang", status = "status",
  iteration = "iterasi", action = "tindakan", components = "komponen",
  ccf_lag = "lead korelasi", median_lead = "median lead", passed = "lolos",
  positive = "positif", naive = "naif", to = "sampai",
  "reference disaggregated from quarterly data" =
    "seri acuan hasil disagregasi data triwulanan",
  "turning points +/- 1 month" = "titik balik \u00b11 bulan",
  score = "skor", cutoff = "titik potong", median_lead_in = "lead dalam sampel",
  median_lead_out = "lead sesudahnya", pct_led_out = "didahului sesudahnya",
  n_tp_out = "titik balik sesudahnya", lead_gap = "selisih lead",
  note = "catatan", name = "nama", reasons = "alasan",
  # plots
  "index (first value = 100)" = "indeks (nilai pertama = 100)",
  "normalised cycle" = "siklus ternormalisasi", moved = "digeser",
  "reference contraction" = "kontraksi seri acuan",
  "lead of the cross-correlation peak (periods)" =
    "lead puncak korelasi silang (periode)",
  "lead (periods; > 0: leads)" = "lead (periode; > 0: mendahului)",
  correlation = "korelasi",
  "index (long-term average = 100)" = "indeks (rerata jangka panjang = 100)",
  "composite leading indicator" = "indikator komposit pendahulu",
  "coincident index" = "indeks sejalan",
  "reference cycle" = "siklus acuan", weight = "bobot",
  composite = "komposit", "step (number of components)" =
    "langkah (jumlah komponen)", passes = "lolos", fails = "gagal",
  "probability of contraction" = "peluang kontraksi",
  "false positive rate" = "laju positif palsu",
  "true positive rate" = "laju positif benar",
  "cut-off" = "titik potong", "median lead (periods)" = "median lead (periode)",
  "in sample" = "dalam sampel", "after cut-off" = "sesudah titik potong",
  "no composite" = "tanpa komposit", reference = "acuan"
)

# OECD rationales described in Indonesian.
oecd_rationales_id <- c(
  early_stage = "Tahap awal: tahap awal produksi (pesanan baru, izin bangunan)",
  rapid_response = paste("Cepat merespons: bereaksi cepat terhadap aktivitas",
                         "(jam kerja, laba, stok)"),
  expectations = paste("Peka ekspektasi: ekspektasi pelaku ekonomi (harga",
                       "saham, survei keyakinan)"),
  prime_mover = paste("Penggerak utama: kebijakan moneter dan kondisi",
                      "eksternal (uang beredar, nilai tukar perdagangan)")
)

# Vectorised translator of table and plot phrases (identity for English).
phrase_translator <- function(language) {
  if (language == "en") return(function(x) x)
  function(x) {
    out <- unname(app_phrases_id[x])
    dropped <- grepl("^dropped ", x)
    out[dropped] <- sub("^dropped ", "dibuang ", x[dropped])
    ifelse(is.na(out), x, out)
  }
}

# Translate the column names of a data frame.
translate_names <- function(df, p) {
  names(df) <- p(names(df))
  df
}

# Labels of the failed leading criteria (the `reasons` column).
reason_phrases_id <- c(
  matched = "titik balik berpasangan", ccf = "lead korelasi silang",
  lead = "median lead", consistency = "konsistensi", missed = "terlewat",
  extra = "ekstra", concordance = "konkordansi", granger = "Granger",
  "longer lead (over 8 months)" = "lead lebih panjang (di atas 8 bulan)"
)

translate_reasons <- function(x, language) {
  if (language == "en") return(x)
  vapply(strsplit(x, ", ", fixed = TRUE), function(r) {
    lab <- unname(reason_phrases_id[r])
    paste(ifelse(is.na(lab), r, lab), collapse = ", ")
  }, character(1))
}
