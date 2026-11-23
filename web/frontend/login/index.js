async function handleLogin(event) {
  event.preventDefault();

  const usernameInput = document.getElementById("username");
  const passwordInput = document.getElementById("password");
  const usernameError = document.getElementById("usernameError");
  const passwordError = document.getElementById("passwordError");

  // 🔄 تصفير الأخطاء القديمة
  usernameError.style.display = "none";
  passwordError.style.display = "none";
  usernameInput.classList.remove("input-error");
  passwordInput.classList.remove("input-error");

  let hasError = false;

  const usernameValue = usernameInput.value.trim();
  const passwordValue = passwordInput.value;

  // ✅ تحقق من اسم المستخدم / الإيميل
  if (!usernameValue) {
    usernameError.textContent = "Please enter your username or email.";
    usernameError.style.display = "block";
    usernameInput.classList.add("input-error");
    hasError = true;
  }

  // ✅ تحقق من الباسورد
  if (passwordValue.length < 6) {
    passwordError.textContent = "Password must be at least 6 characters.";
    passwordError.style.display = "block";
    passwordInput.classList.add("input-error");
    hasError = true;
  }

  if (hasError) return false;

  try {
    const response = await fetch("/api/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        username: usernameValue,
        password: passwordValue,
      }),
    });

    let data;
    try {
      data = await response.json();
    } catch (e) {
      console.error("Failed to parse JSON from backend:", e);
      passwordError.textContent = "Unexpected server response.";
      passwordError.style.display = "block";
      return false;
    }

    // ❌ إذا السيرفر رجع خطأ أو success = false
    if (!response.ok || !data.success) {
      if (response.status === 400 || response.status === 401) {
        passwordError.textContent = "Invalid username or password.";
      } else {
        passwordError.textContent = "Server error. Please try again later.";
      }

      passwordError.style.display = "block";
      passwordInput.classList.add("input-error");

      // 🛠 تفاصيل إضافية للمطور فقط أثناء العمل على localhost
      if (
        window.location.hostname === "localhost" ||
        window.location.hostname === "127.0.0.1"
      ) {
        console.warn("Login failed:", { status: response.status, data });
      }

      return false;
    }

    // ✅ هنا تسجيل الدخول ناجح

    // امسح أي حالة قديمة للجلسة
    localStorage.removeItem("cyberEyeLoggedIn");
    sessionStorage.removeItem("cyberEyeLoggedIn");

    // ✅ بما إنه ما عاد في Remember me -> نخليها جلسة مؤقتة دائمًا
    sessionStorage.setItem("cyberEyeLoggedIn", "true");

    // ✅ لا نحفظ اليوزر/الإيميل إطلاقاً
    localStorage.removeItem("cyberEyeLastUsername");

    // ✅ بعد النجاح، ودّيه على الداشبورد
    window.location.href = "/dashboard/";

    return true;
  } catch (err) {
    console.error("Login error (network/CORS):", err);
    alert("Server error. Please try again later.");
    return false;
  }
}

document.addEventListener("DOMContentLoaded", () => {
  // ✅ تفريغ الحقول لتقليل autofill قدر الإمكان
  const usernameInput = document.getElementById("username");
  const passwordInput = document.getElementById("password");
  if (usernameInput) usernameInput.value = "";
  if (passwordInput) passwordInput.value = "";

  // ✅ لو هو أصلاً مسجل دخول (بغض النظر local أو session)
  const alreadyLoggedIn =
    localStorage.getItem("cyberEyeLoggedIn") === "true" ||
    sessionStorage.getItem("cyberEyeLoggedIn") === "true";

  // لو مسجل دخول أساساً، ودّيه مباشرة للداشبورد
  if (alreadyLoggedIn) {
    window.location.href = "/dashboard/";
    return;
  }

  const form = document.getElementById("loginForm");
  if (form) {
    form.addEventListener("submit", handleLogin);
  }

  // ✅ لا تعبئة تلقائية لليوزر/الإيميل
  localStorage.removeItem("cyberEyeLastUsername");
});
