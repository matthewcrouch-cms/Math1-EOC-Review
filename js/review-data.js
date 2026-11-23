// Review topics shown in the Review Hub and the "📘 Review" drawer next to each question.
// Domains and weights come from the Math 1 EOC test specs.
(function () {
  const f = (a, b) => `<span class="fr"><span>${a}</span><span>${b}</span></span>`;
  const T = {};
  const add = (id, domain, name, blurb, body) => { T[id] = { id, domain, name, blurb, body }; };

  // ---------- Number & Quantity / Algebra ----------
  add("lin-eq", "A", "Solving linear equations & inequalities", "Distribute, combine, isolate. Watch for no solution / all reals.", `
    <h3>Steps</h3><ul>
      <li><b>Distribute</b> (including negatives!), then <b>combine like terms</b> on each side.</li>
      <li>Move variable terms to one side, numbers to the other. Divide last.</li>
      <li>Fractions? Multiply every term by the denominator (or cross-multiply when it's fraction = fraction).</li>
      <li><b>Inequalities:</b> same steps, but if you multiply or divide by a <b>negative</b>, flip the sign.</li></ul>
    <h3>Special results</h3><ul>
      <li>Variables cancel and you get something true (5 = 5) → <b>all real numbers</b> (infinitely many).</li>
      <li>Variables cancel and you get something false (6 = 1) → <b>no solution</b>.</li></ul>
    <div class="ex"><b>Example:</b> −3(x − 2) + x &gt; 14 − 6x<br>−3x + 6 + x &gt; 14 − 6x → −2x + 6 &gt; 14 − 6x → 4x &gt; 8 → <b>x &gt; 2</b></div>
    <div class="tipbox"><b>Desmos check:</b> graph y = (left side) and y = (right side). The x-value where they cross is the solution.</div>`);
  add("ineq", "A", "Writing equations & inequalities", "Turn words into math: once vs. per item, “at most” vs. “at least.”", `
    <h3>Translate the words</h3><ul>
      <li>A cost paid <b>once</b> (fee, admission, part) is a plain number. A cost <b>per</b> item/hour gets the variable: 4r, 40x.</li>
      <li>“at most”, “no more than”, “not exceed” → <b>≤</b></li>
      <li>“at least”, “no less than”, “minimum” → <b>≥</b></li>
      <li>“more than” → &gt; &nbsp; “less than” → &lt;</li></ul>
    <div class="ex"><b>Example:</b> A gym charges a $30 sign-up fee plus $15 per month. Spend no more than $150 → <b>30 + 15m ≤ 150</b></div>
    <div class="warnbox"><b>Trap:</b> don't put the variable on the one-time cost (30m + 15 is backwards).</div>`);
  add("literal", "A", "Literal equations (solve for a letter)", "Treat the other letters like numbers and undo operations.", `
    <h3>Steps</h3><ul>
      <li>Circle the letter you're solving for. Everything else acts like a number.</li>
      <li>Undo addition/subtraction first, then multiplication/division.</li></ul>
    <div class="ex"><b>Example:</b> Solve A = 3h + 4k for k.<br>A − 3h = 4k → <b>k = ${f("A − 3h", "4")}</b></div>
    <div class="ex"><b>Example:</b> Solve 3x − 6y = 24 for y.<br>−6y = −3x + 24 → <b>y = ${f("1", "2")}x − 4</b> (divide <i>every</i> term by −6)</div>`);
  add("systems", "A", "Systems of equations & inequalities", "Where do the lines intersect? Substitution, elimination, Desmos.", `
    <h3>Solve a system</h3><ul>
      <li><b>Desmos:</b> type both equations, click the intersection point. Fastest on the calculator section!</li>
      <li><b>Substitution:</b> solve one equation for a variable, plug into the other.</li>
      <li><b>Elimination:</b> multiply so one variable has opposite coefficients (9y and −9y), then add.</li></ul>
    <h3>How many solutions?</h3><ul>
      <li>Different slopes → <b>one</b> solution.</li>
      <li>Same slope, different intercept (parallel) → <b>no</b> solution.</li>
      <li>Same line (one equation is a multiple of the other) → <b>infinitely many</b>.</li></ul>
    <h3>Word problems</h3><ul>
      <li>Usually one equation counts <b>things</b> (tickets, people, pounds) and one counts <b>money</b>.</li>
      <li>Money equation: price × quantity for each type.</li></ul>
    <div class="ex"><b>Example:</b> 150 tickets sold; kids $4, adults $9; $1,000 total.<br><b>k + a = 150</b> and <b>4k + 9a = 1000</b></div>
    <h3>Inequalities on a graph</h3><ul>
      <li>≤ or ≥ → <b>solid</b> line. &lt; or &gt; → <b>dashed</b> line.</li>
      <li>Solved for y: “&gt; above” and “&lt; below.” Or test the point (0, 0).</li></ul>`);
  add("exp-rules", "A", "Exponent rules", "Multiply → add exponents. Power of a power → multiply.", `
    <h3>Rules</h3><ul>
      <li>x<sup>a</sup> · x<sup>b</sup> = x<sup>a+b</sup> &nbsp;&nbsp; ${f("x<sup>a</sup>", "x<sup>b</sup>")} = x<sup>a−b</sup></li>
      <li>(x<sup>a</sup>)<sup>b</sup> = x<sup>ab</sup> &nbsp;&nbsp; (xy)<sup>a</sup> = x<sup>a</sup>y<sup>a</sup> — the power goes on <b>every</b> factor, including the number.</li>
      <li>x<sup>0</sup> = 1 &nbsp;&nbsp; x<sup>−a</sup> = ${f("1", "x<sup>a</sup>")}</li></ul>
    <div class="ex"><b>Example:</b> (3a<sup>4</sup>b)<sup>3</sup> = 3<sup>3</sup>a<sup>12</sup>b<sup>3</sup> = <b>27a<sup>12</sup>b<sup>3</sup></b></div>
    <div class="warnbox"><b>Trap:</b> 3<sup>3</sup> is 27, not 9. Coefficients get raised to the power too.</div>`);
  add("polys", "A", "Polynomial operations", "Add/subtract like terms; multiply every term by every term.", `
    <h3>Add / subtract</h3><ul>
      <li>Combine like terms (same variable and exponent).</li>
      <li>Subtracting a polynomial: distribute the minus sign to <b>every</b> term inside.</li></ul>
    <h3>Multiply</h3><ul>
      <li>Each term in the first times each term in the second (FOIL / box method).</li>
      <li>(a + b)<sup>2</sup> = a<sup>2</sup> + 2ab + b<sup>2</sup> — don't forget the middle term!</li></ul>
    <div class="ex"><b>Example:</b> (2x − 3)(x + 4) = 2x<sup>2</sup> + 8x − 3x − 12 = <b>2x<sup>2</sup> + 5x − 12</b></div>
    <div class="ex"><b>Example:</b> (x<sup>2</sup> + 4x − 1) − (x<sup>2</sup> − 2x + 7) = x<sup>2</sup> + 4x − 1 − x<sup>2</sup> + 2x − 7 = <b>6x − 8</b></div>
    <div class="tipbox"><b>Desmos check:</b> graph the original and your answer. Same graph = equivalent.</div>`);
  add("factor", "A", "Factoring & solving quadratics", "GCF first, then two numbers; zeros come from factors.", `
    <h3>Factor</h3><ul>
      <li>Always pull out the <b>GCF</b> first: 3x<sup>2</sup> + 6x − 24 = 3(x<sup>2</sup> + 2x − 8).</li>
      <li>x<sup>2</sup> + bx + c: two numbers that multiply to c and add to b.</li>
      <li>ax<sup>2</sup> + bx + c: multiply a·c, find two numbers, split the middle, group.</li>
      <li>Difference of squares: a<sup>2</sup> − b<sup>2</sup> = (a − b)(a + b). Perfect square: x<sup>2</sup> + 6x + 9 = (x + 3)<sup>2</sup>.</li></ul>
    <h3>Solve (find zeros / roots / x-intercepts)</h3><ul>
      <li>Set = 0, factor, set each factor = 0. A factor (x − 7) gives zero x = 7; (x + 2) gives x = −2.</li>
      <li>Squared already? Take ± square roots: (x − 1)<sup>2</sup> = 16 → x − 1 = ±4 → x = 5 or x = −3.</li>
      <li>Going backwards: zeros 4 and −1 → f(x) = (x − 4)(x + 1) = x<sup>2</sup> − 3x − 4.</li></ul>
    <div class="tipbox"><b>Desmos:</b> graph y = the quadratic and click the gray x-intercept points.</div>`);
  // ---------- Functions ----------
  add("func-notation", "F", "Function notation, domain & range", "f(3) means plug in 3. Domain = x (wide), range = y (tall).", `
    <h3>Function notation</h3><ul>
      <li>f(4) means “replace every x with 4.” Use parentheses: 3(4)<sup>2</sup> − 5(4) + 1 = 48 − 20 + 1 = 29.</li>
      <li>f(x) = g(x) means “where do the graphs meet?”</li>
      <li>A relation is a function when each <b>x</b> has only one <b>y</b>. A repeated x with a different y breaks it.</li></ul>
    <h3>Domain & range</h3><ul>
      <li><b>Domain:</b> x-values — how <b>wide</b> the graph is (left to right).</li>
      <li><b>Range:</b> y-values — how <b>tall</b> the graph is (bottom to top).</li>
      <li>Real-world: can x be a fraction? (sodas, people → integers only). Can it be negative? (time, items → x ≥ 0).</li></ul>
    <h3>Key features</h3><ul>
      <li>Increasing/decreasing intervals use <b>x-values</b>, read left to right.</li>
      <li>Positive = graph above the x-axis; negative = below.</li>
      <li>x-intercept (x, 0); y-intercept (0, y).</li></ul>
    <div class="tipbox"><b>Desmos:</b> type the function, then click the gear → table, or type f(3) on a new line.</div>`);
  add("lin-func", "F", "Linear functions & their graphs", "y = mx + b: slope m, y-intercept b. Intercepts: (x, 0) and (0, y).", `
    <h3>Forms</h3><ul>
      <li>Slope-intercept: <b>y = mx + b</b> (m = slope, b = y-intercept).</li>
      <li>Standard form Ax + By = C: solve for y to see the slope, or use slope = −A/B.</li>
      <li>Slope from two points: m = ${f("y<sub>2</sub> − y<sub>1</sub>", "x<sub>2</sub> − x<sub>1</sub>")}.</li></ul>
    <h3>Write an equation</h3><ul>
      <li>Find m. Plug m and a point into y = mx + b and solve for b.</li></ul>
    <div class="ex"><b>Example:</b> slope ${f("3", "4")} through (8, −1): −1 = (${f("3", "4")})(8) + b → −1 = 6 + b → <b>y = ${f("3", "4")}x − 7</b></div>
    <h3>Intercepts</h3><ul>
      <li>x-intercept: set y = 0. y-intercept: set x = 0. Write them as points!</li></ul>
    <h3>Linear or not?</h3><ul>
      <li>Linear: <b>adds</b> the same amount each step ($8 per hour, 3 inches per week).</li>
      <li>Exponential: <b>multiplies</b> by the same amount (5% interest, half of the amount each day).</li></ul>`);
  add("par-perp", "F", "Parallel & perpendicular lines", "Parallel: same slope. Perpendicular: opposite reciprocal.", `
    <ul><li><b>Parallel:</b> same slope. y = 3x + 1 ∥ y = 3x − 8.</li>
      <li><b>Perpendicular:</b> opposite reciprocal (flip and change the sign). 5/2 ⊥ −2/5. Slopes multiply to −1.</li>
      <li>Then use the point to find b.</li></ul>
    <div class="ex"><b>Example:</b> ⊥ to y = 3x − 2 through (0, 4): slope −1/3, b = 4 → y = −⅓x + 4 → <b>x + 3y = 12</b></div>
    <div class="tipbox"><b>Standard form shortcut:</b> Ax + By = C has slope −A/B. 4x − 5y = 9 → slope 4/5.</div>`);
  add("roc", "F", "Average rate of change", "Change in y ÷ change in x. For a line it's the slope.", `
    <ul><li>Average rate of change from x = a to x = b: ${f("f(b) − f(a)", "b − a")}</li>
      <li>From a table: pick the two rows. From a graph: read the two points.</li>
      <li>Units: (y-units) per (x-unit): feet per second, households per year.</li>
      <li>Linear function → the rate of change is the same everywhere (the slope).</li></ul>
    <div class="ex"><b>Example:</b> h(t) = 2t<sup>2</sup> from 1 to 4 s: ${f("h(4) − h(1)", "4 − 1")} = ${f("32 − 2", "3")} = <b>10 ft/s</b></div>`);
  add("interpret", "F", "Interpreting parts of a model", "Starting value (y-intercept) vs. rate (slope / factor).", `
    <ul><li>In <b>y = mx + b</b>: b is the value at the start (x = 0); m is the change per 1 unit of x.</li>
      <li>In <b>y = a(b)<sup>x</sup></b>: a is the starting amount; b is the multiplier each step.</li>
      <li>In a quadratic like −16t<sup>2</sup> + 40t + 6: the constant (6) is the height at t = 0 — where it started.</li></ul>
    <div class="ex"><b>Example:</b> C(m) = 12m + 50 dollars after m months → <b>$50</b> at the start, <b>$12</b> added each month.</div>`);
  add("sequences", "F", "Arithmetic & geometric sequences", "Arithmetic adds d; geometric multiplies by r.", `
    <h3>Arithmetic (add the same number d)</h3><ul>
      <li>Explicit: <b>a<sub>n</sub> = a<sub>1</sub> + d(n − 1)</b></li>
      <li>Recursive: a<sub>n</sub> = a<sub>n−1</sub> + d, with a<sub>1</sub> given.</li></ul>
    <h3>Geometric (multiply by the same number r)</h3><ul>
      <li>Explicit: <b>a<sub>n</sub> = a<sub>1</sub>(r)<sup>n−1</sup></b></li>
      <li>Recursive: a<sub>n</sub> = a<sub>n−1</sub> · r</li></ul>
    <div class="ex"><b>Example:</b> 7, 10, 13, 16, … → a<sub>1</sub> = 7, d = 3 → <b>f(n) = 7 + 3(n − 1)</b></div>
    <div class="ex"><b>Example:</b> 500, 400, 320, … → 400 ÷ 500 = 0.8 → <b>a<sub>n</sub> = a<sub>n−1</sub>(0.8)</b></div>
    <div class="tipbox">Not sure? Test choices by plugging in n = 1 and n = 2.</div>`);
  add("expo", "F", "Exponential growth & decay", "y = a(b)^x. b > 1 grows, 0 < b < 1 decays. Rate = |b − 1|.", `
    <ul><li><b>y = a(b)<sup>x</sup></b>: a = starting value (y-intercept), b = growth/decay factor.</li>
      <li>b &gt; 1 → <b>growth</b> by (b − 1). 1.06 → grows 6%.</li>
      <li>0 &lt; b &lt; 1 → <b>decay</b> by (1 − b). 0.92 → decays 8%. 0.3 → keeps 30%, loses 70%.</li>
      <li>Percent to factor: grow r% → 1 + r; decay r% → 1 − r. 2.5% interest → 1.025.</li>
      <li>From a table: y-value at x = 0 is a; divide consecutive y's to get b.</li>
      <li>Graph: never touches the x-axis (no x-intercept); y-intercept is (0, a).</li></ul>
    <div class="ex"><b>Example:</b> $200 growing 3% per year for 10 years → 200(1.03)<sup>10</sup> ≈ <b>$268.78</b></div>
    <div class="warnbox"><b>Trap:</b> “doubles”/“triples” is the factor (2, 3), not a percent. Start with the amount actually invested (if $300 of $1,000 is spent, the start is $700).</div>`);
  add("quad-func", "F", "Quadratic functions & graphs", "Vertex, zeros, y-intercept, opens up or down.", `
    <ul><li>Opens <b>up</b> if a &gt; 0 (minimum), <b>down</b> if a &lt; 0 (maximum).</li>
      <li><b>Vertex</b> = turning point. Increasing/decreasing switch at the vertex's x-value.</li>
      <li><b>Zeros</b> (x-intercepts) come from factors. Graph with zeros −2 and 6 → (x + 2)(x − 6).</li>
      <li><b>Domain:</b> all real numbers. <b>Range:</b> y ≥ (vertex y) if it opens up; y ≤ (vertex y) if it opens down.</li>
      <li>Symmetric: points the same distance from the vertex have the same height.</li></ul>
    <div class="tipbox"><b>Desmos:</b> click the graph to see the vertex and intercepts as gray points.</div>`);
  // ---------- Geometry ----------
  add("coord-geo", "G", "Coordinate geometry", "Distance (Pythagorean theorem), midpoint vs. endpoint, perimeter & area.", `
    <h3>Distance</h3><ul>
      <li>Draw the right triangle: legs = change in x and change in y. d = √(Δx<sup>2</sup> + Δy<sup>2</sup>).</li>
      <li>Perimeter = add all sides. Classify triangles by side lengths (two equal → isosceles).</li></ul>
    <h3>Midpoint vs. endpoint</h3><ul>
      <li><b>Midpoint:</b> average the x's and the y's: (${f("x<sub>1</sub> + x<sub>2</sub>", "2")}, ${f("y<sub>1</sub> + y<sub>2</sub>", "2")}).</li>
      <li><b>Missing endpoint:</b> find the step from the known endpoint to the midpoint, then take that same step again.</li>
      <li>Center of a circle = midpoint of a diameter.</li></ul>
    <div class="ex"><b>Example:</b> A(1, −2), midpoint M(4, 3). Step A→M = (3, 5). B = M + (3, 5) = <b>(7, 8)</b></div>
    <h3>Area on a grid</h3><ul><li>Box it in: rectangle area minus the corner right triangles.</li></ul>`);
  // ---------- Statistics ----------
  add("stats-1var", "S", "One-variable statistics", "Center, spread, shape, outliers. Box plots, dot plots, histograms.", `
    <h3>Center</h3><ul>
      <li><b>Symmetric</b> → use the <b>mean</b> and standard deviation.</li>
      <li><b>Skewed</b> or outliers → use the <b>median</b> and IQR. An outlier pulls the mean, not the median.</li></ul>
    <h3>Shape</h3><ul><li>Skew is named for the <b>tail</b>: tail on the left → skewed left.</li></ul>
    <h3>Box plots</h3><ul>
      <li>Five-number summary: min, Q1, median, Q3, max. <b>IQR = Q3 − Q1</b>, range = max − min.</li>
      <li>Outlier: below Q1 − 1.5·IQR or above Q3 + 1.5·IQR.</li>
      <li>Narrower box/whiskers = more consistent. Box plots can't tell you totals or counts.</li></ul>
    <h3>Mean problems</h3><ul><li>Needed total = mean × number of values. Missing score = total − sum you have.</li></ul>
    <div class="tipbox"><b>Desmos:</b> type a list like L = [8, 11, 12, 10] then mean(L), median(L), stdev(L).</div>`);
  add("regression", "S", "Scatter plots, regression & correlation", "See a table? Desmos regression. r near ±1 = strong.", `
    <ul><li><b>Linear regression in Desmos:</b> + → table, type the data, then on a new line type <b>y<sub>1</sub> ~ mx<sub>1</sub> + b</b>.</li>
      <li>Desmos shows m, b, and r. Use the regression line to predict: plug in x.</li>
      <li><b>r</b> (correlation coefficient) is between −1 and 1. Sign = direction. Close to ±1 = strong; close to 0 = weak.</li>
      <li>Rough guide: |r| ≥ 0.8 strong, 0.5–0.8 moderate, below 0.5 weak.</li>
      <li>Correlation does not prove causation.</li></ul>`);
  // ---------- EOC strategy pages ----------
  add("eoc-strategies", "X", "Biggest bang for your buck", "Test-taking strategies for the Math 1 EOC.", `
    <ol>
      <li>Use the <b>keywords</b> and the given equations or points.</li>
      <li>Make sure you're answering the question being asked.</li>
      <li>Know how to find x- and y-intercepts: <b>(x, 0)</b> and <b>(0, y)</b>.</li>
      <li>Domain (x — how wide). Range (y — how tall).</li>
      <li>Shading: “&gt; above” and “&lt; below.”</li>
      <li>Systems! Where do the lines intersect?</li>
      <li>Graph points and solve distances with the Pythagorean Theorem.</li>
      <li>Be careful if you're supposed to find the <b>midpoint</b> or the <b>endpoint</b>.</li>
      <li>If you're not certain, prove answers wrong based on what you know. Narrow down from there.</li>
      <li>Enter <b>all</b> functions/equations into Desmos. Click the gear icon, then table, to find specific values.</li>
      <li><b>See a table? Plug it into Desmos.</b> Use the regression for the line of best fit.</li></ol>
    <h3>3 types of functions</h3><ul>
      <li><b>Linear</b> — adding and subtracting from the y-intercept.</li>
      <li><b>Exponential</b> — multiplying and dividing from the y-intercept.</li>
      <li><b>Quadratic</b> — opens up or down, y-intercept, zeros, vertex.</li></ul>`);
  add("eoc-expect", "X", "What to expect on test day", "Format, timing, calculator rules, pacing.", `
    <ul><li><b>4 hours</b> to finish. <b>60 questions</b>: questions 1–19 are <b>calculator INACTIVE</b> (no Desmos, no handheld); questions 20–60 are <b>ACTIVE</b> (use Desmos).</li>
      <li>Two 2-minute breaks. You can take a break with your teacher's approval.</li>
      <li>Show work for every question. Personal technology is collected.</li></ul>
    <h3>Pacing</h3><ul>
      <li><b>First 60 min:</b> questions 1–19 (inactive). Goal: confident on 10+.</li>
      <li><b>Next 60 min:</b> finish inactive, click <b>Review</b>, submit, then start 20–60.</li>
      <li><b>Last 2 hours:</b> questions 20–60 with Desmos. Goal: confident on 21+. Click <b>Review</b> before you submit.</li>
      <li>Unsure? Guess as you go and <b>flag</b> it to come back to.</li></ul>
    <h3>What's on it</h3>
    <table class="grid"><tr><th>Domain</th><th>% of test</th><th># of questions</th></tr>
      <tr><td>Number & Quantity / Algebra</td><td>36–40%</td><td>22–24</td></tr>
      <tr><td>Functions</td><td>32–36%</td><td>19–22</td></tr>
      <tr><td>Geometry</td><td>8–12%</td><td>5–7</td></tr>
      <tr><td>Statistics & Probability</td><td>18–20%</td><td>11–12</td></tr></table>
    <h3>More practice</h3><ul>
      <li><a href="https://data.ncsu.edu/nctest/Destination.html" target="_blank" rel="noopener">NC Practice Test</a> → click on the released test.</li>
      <li>Released test video support: <a href="https://bit.ly/M1inactive" target="_blank" rel="noopener">Inactive</a> · <a href="https://bit.ly/M1activeNCDesmos" target="_blank" rel="noopener">Active (Desmos)</a></li></ul>`);

  window.EOC_REVIEW = {
    topics: T,
    domains: [
      { id: "X", name: "Test-day essentials", weight: "" },
      { id: "A", name: "Number & Quantity / Algebra", weight: "36–40% of the EOC" },
      { id: "F", name: "Functions", weight: "32–36%" },
      { id: "G", name: "Geometry", weight: "8–12%" },
      { id: "S", name: "Statistics & Probability", weight: "18–20%" },
    ],
  };
})();
